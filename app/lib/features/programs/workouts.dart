import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_dialog.dart';
import '../../core/widgets/kpi.dart';

/// Saisie d'une séance réalisée (liée à un programme ou libre). Renvoie `true` si elle a été enregistrée.
Future<bool> logWorkout(BuildContext context, {int? programId, String? title}) async {
  final r = await formDialog(context, title == null ? 'Séance libre' : 'J\'ai fait : $title', const [
    DField('done_on', 'Date', type: DType.date, required: true),
    DField('duration', 'Durée (minutes)', type: DType.integer, min: 1, max: 600),
    DField('rpe', 'Difficulté ressentie', type: DType.slider, min: 1, max: 10, initial: 6),
    DField('notes', 'Comment ça s\'est passé ?', type: DType.multiline),
  ], submit: (v) => Api.call('POST', 'workouts', {...v, 'program_id': programId}));
  return r != null;
}

/// Ouvre la saisie du commentaire du coach sur une séance. Renvoie `true` s'il a été envoyé.
Future<bool> commentWorkout(BuildContext context, Json w, {String title = 'Commentaire'}) async {
  final r = await formDialog(
    context,
    title,
    [DField('comment', 'Retour, conseils…', type: DType.multiline, initial: w['coach_comment'])],
    ok: 'Envoyer',
    submit: (v) => Api.call('POST', 'workouts/${w['id']}/feedback', v),
  );
  return r != null;
}

/// Statistiques d'une liste de séances : cette semaine (depuis lundi), minutes du mois, total.
class WorkoutStats {
  final int thisWeek, total;
  final double monthMinutes;

  factory WorkoutStats(List<Json> list, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final weekStart = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
    final month = todayIso(n).substring(0, 7);
    return WorkoutStats._(
      list.where((w) => !(DateTime.tryParse('${w['done_on']}') ?? DateTime(2000)).isBefore(weekStart)).length,
      list.length,
      list.where((w) => '${w['done_on']}'.startsWith(month)).fold<double>(0, (s, w) => s + toDouble(w['duration'])),
    );
  }

  const WorkoutStats._(this.thisWeek, this.total, this.monthMinutes);
}

/// Carte d'une séance réalisée, avec le commentaire éventuel du coach.
class WorkoutCard extends StatelessWidget {
  final Json w;
  final VoidCallback? onComment, onDelete;
  const WorkoutCard(this.w, {super.key, this.onComment, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: Gaps.page,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: Icon(Icons.check_circle, color: AppColors.of(context).success)),
                Gaps.w8,
                Expanded(
                  child: Text(
                    '${w['done_on']}${w['program_title'] == null ? '' : ' · ${w['program_title']}'}',
                    style: t.titleSmall,
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Supprimer la séance',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: onDelete,
                  ),
              ],
            ),
            Text(
              [
                if (w['duration'] != null) '${w['duration']} min',
                if (w['rpe'] != null) 'difficulté ${w['rpe']}/10',
              ].join(' · '),
            ),
            if (w['notes'] != null)
              Padding(
                padding: const EdgeInsets.only(top: Gaps.xs),
                child: Text('${w['notes']}'),
              ),
            if (w['coach_comment'] != null)
              Padding(
                padding: const EdgeInsets.only(top: Gaps.sm),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Semantics(
                      label: 'Commentaire du coach',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sports, size: 18, color: cs.onSecondaryContainer),
                          Gaps.w8,
                          Expanded(
                            child: Text('${w['coach_comment']}', style: TextStyle(color: cs.onSecondaryContainer)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (onComment != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onComment,
                  icon: const Icon(Icons.rate_review),
                  label: Text(w['coach_comment'] == null ? 'Commenter' : 'Modifier le commentaire'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Liste des séances d'un membre (les siennes, ou celles d'un client pour son coach).
class WorkoutList extends StatefulWidget {
  /// `null` = moi.
  final int? userId;
  const WorkoutList({super.key, this.userId});

  @override
  State<WorkoutList> createState() => WorkoutListState();
}

class WorkoutListState extends State<WorkoutList> with AsyncLoadMixin<WorkoutList, List<Json>> {
  bool get mine => widget.userId == null || widget.userId == Api.myId;

  @override
  Future<List<Json>> fetch() => Api.list(Api.withQuery('workouts', {'user_id': widget.userId, 'limit': 100}));

  Future<void> comment(Json w) async {
    if (await commentWorkout(context, w)) await reload();
  }

  Future<void> remove(Json w) async {
    if (!await confirm(context, 'Supprimer cette séance ?', ok: 'Supprimer')) return;
    if (mounted && await attempt(context, () => Api.call('DELETE', 'workouts/${w['id']}'))) await reload();
  }

  @override
  Widget build(BuildContext context) => AsyncStateView(
    loading: loading,
    error: error,
    data: data,
    onRetry: reload,
    builder: (context, list) {
      final s = WorkoutStats(list);
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, 88),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            KpiGrid(
              columns: 3,
              children: [
                KpiCard(icon: Icons.date_range, label: 'Cette semaine', value: '${s.thisWeek}'),
                KpiCard(icon: Icons.timer, label: 'Minutes (mois)', value: s.monthMinutes.toStringAsFixed(0)),
                KpiCard(icon: Icons.emoji_events, label: 'Total', value: '${s.total}'),
              ],
            ),
            const SectionTitle('Historique'),
            if (list.isEmpty)
              Card(
                child: EmptyState(
                  icon: Icons.history,
                  text: mine
                      ? 'Aucune séance enregistrée.\nAppuyez sur « Séance » pour noter votre entraînement.'
                      : 'Aucune séance sur vos programmes pour le moment.',
                ),
              ),
            for (final w in list)
              WorkoutCard(
                w,
                onDelete: mine ? () => remove(w) : null,
                onComment: !mine && w['coach_id'] == Api.myId ? () => comment(w) : null,
              ),
          ],
        ),
      );
    },
  );
}

/// Historique d'entraînement personnel.
class WorkoutHistoryPage extends StatefulWidget {
  const WorkoutHistoryPage({super.key});

  @override
  State<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends State<WorkoutHistoryPage> {
  final key = GlobalKey<WorkoutListState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes séances'),
        actions: [RefreshButton(onPressed: () => key.currentState?.reload())],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Séance'),
        onPressed: () async {
          if (await logWorkout(context)) await key.currentState?.reload();
        },
      ),
      body: WorkoutList(key: key),
    );
  }
}
