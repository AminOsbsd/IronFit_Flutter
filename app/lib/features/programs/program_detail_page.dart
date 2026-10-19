import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_dialog.dart';
import '../../core/widgets/kpi.dart';
import 'program_list.dart';
import 'workouts.dart';

List<DField> exerciseFields([Json? e]) => [
  DField('name', 'Exercice', required: true, initial: e?['name']),
  DField('day', 'Jour / bloc (ex. A, Lundi)', initial: e?['day']),
  DField('sets', 'Séries', type: DType.integer, max: 50, initial: e?['sets']),
  DField('reps', 'Répétitions (ex. 8-12, 45 s)', initial: e?['reps']),
  DField('load', 'Charge (ex. 40 kg)', initial: e?['load']),
  DField('rest', 'Repos (ex. 90 s)', initial: e?['rest']),
  DField('notes', 'Notes', initial: e?['notes']),
];

/// « 4 × 8-12 · 40 kg · repos 90 s ».
String exerciseLine(Json e) => [
  if (e['sets'] != null || e['reps'] != null) '${e['sets'] ?? '?'} × ${e['reps'] ?? '?'}',
  if (e['load'] != null) '${e['load']}',
  if (e['rest'] != null) 'repos ${e['rest']}',
].join(' · ');

/// Exercices regroupés par jour / bloc, dans l'ordre d'apparition.
Map<String, List<Json>> groupByDay(List<Json> items) {
  final groups = <String, List<Json>>{};
  for (final e in items) {
    groups.putIfAbsent('${e['day'] ?? ''}', () => []).add(e);
  }
  return groups;
}

/// Détail d'un programme : exercices, séances réalisées, commentaires du coach.
class ProgramDetailPage extends StatefulWidget {
  final int id;
  const ProgramDetailPage(this.id, {super.key});

  @override
  State<ProgramDetailPage> createState() => _ProgramDetailPageState();
}

class _ProgramDetailPageState extends State<ProgramDetailPage> with AsyncLoadMixin<ProgramDetailPage, Json> {
  Json get p => data ?? const {};
  bool get canEdit => asBool(p['can_edit']);
  List<Json> listOf(String k) => jsonList(p, k);

  @override
  Future<Json> fetch() => Api.get('programs/${widget.id}');

  Future<void> editProgram() async {
    final r = await formDialog(
      context,
      'Modifier le programme',
      programFields(p),
      submit: (v) => Api.call('PUT', 'programs/${widget.id}', {...v, 'active': p['active']}),
    );
    if (r != null) await reload();
  }

  Future<void> toggleActive() async {
    final ok = await attempt(
      context,
      () => Api.call('PUT', 'programs/${widget.id}', {
        'title': p['title'],
        'goal': p['goal'],
        'notes': p['notes'],
        'active': p['active'] == 1 ? 0 : 1,
      }),
    );
    if (ok) await reload();
  }

  Future<void> deleteProgram() async {
    final ok = await confirm(
      context,
      'Supprimer « ${p['title']} » ?',
      body: 'Les exercices seront supprimés. Les séances déjà réalisées restent dans l\'historique.',
      ok: 'Supprimer',
    );
    if (!ok || !mounted) return;
    if (await attempt(context, () => Api.call('DELETE', 'programs/${widget.id}')) && mounted) Navigator.pop(context);
  }

  Future<void> exercise([Json? e]) async {
    final r = await formDialog(
      context,
      e == null ? 'Ajouter un exercice' : 'Modifier l\'exercice',
      exerciseFields(e),
      submit: (v) => e == null
          ? Api.call('POST', 'programs/${widget.id}/exercises', v)
          : Api.call('PUT', 'exercises/${e['id']}', {...v, 'position': e['position']}),
    );
    if (r != null) await reload();
  }

  Future<void> deleteExercise(Json e) async {
    if (!await confirm(context, 'Supprimer « ${e['name']} » ?', ok: 'Supprimer')) return;
    if (mounted && await attempt(context, () => Api.call('DELETE', 'exercises/${e['id']}'))) await reload();
  }

  Future<void> comment(Json w) async {
    if (await commentWorkout(context, w, title: 'Commentaire pour votre client')) await reload();
  }

  List<Widget> content() {
    final items = listOf('items'), workouts = listOf('workouts');
    final canLog = asBool(p['can_log']);
    return [
      Card(
        child: ListTile(
          leading: Icon(p['coach_id'] == null ? Icons.person : Icons.sports),
          title: Text(p['coach_id'] == null ? 'Programme personnel' : 'Coach : ${p['coach_name'] ?? '—'}'),
          subtitle: Text(
            [
              if (!canLog) 'Client : ${p['client_name']}',
              if (p['goal'] != null) 'Objectif : ${p['goal']}',
              if (p['active'] == 0) 'Archivé',
              if (p['notes'] != null) '${p['notes']}',
            ].join('\n'),
          ),
        ),
      ),
      Row(
        children: [
          const Expanded(child: SectionTitle('Exercices')),
          if (canEdit) TextButton.icon(onPressed: exercise, icon: const Icon(Icons.add), label: const Text('Ajouter')),
        ],
      ),
      if (items.isEmpty)
        Card(
          child: EmptyState(
            icon: Icons.fitness_center,
            text: canEdit ? 'Ajoutez le premier exercice.' : 'Aucun exercice pour le moment.',
          ),
        ),
      for (final g in groupByDay(items).entries) ...[
        if (g.key.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gaps.xs, Gaps.sm, Gaps.xs, 2),
            child: Semantics(header: true, child: Text('Bloc ${g.key}', style: Theme.of(context).textTheme.labelLarge)),
          ),
        for (final e in g.value)
          Card(
            child: ListTile(
              title: Text('${e['name']}'),
              subtitle: Text(
                [exerciseLine(e), if (e['notes'] != null) '${e['notes']}'].where((s) => s.isNotEmpty).join('\n'),
              ),
              onTap: canEdit ? () => exercise(e) : null,
              trailing: canEdit
                  ? IconButton(
                      tooltip: 'Supprimer ${e['name']}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => deleteExercise(e),
                    )
                  : null,
            ),
          ),
      ],
      const SectionTitle('Séances réalisées'),
      if (workouts.isEmpty)
        const Card(
          child: EmptyState(icon: Icons.history, text: 'Aucune séance enregistrée.'),
        ),
      for (final w in workouts) WorkoutCard(w, onComment: asBool(p['can_comment']) ? () => comment(w) : null),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(data == null ? 'Programme' : '${p['title']}'),
        actions: [
          if (canEdit)
            PopupMenuButton<String>(
              tooltip: 'Actions du programme',
              onSelected: (v) => switch (v) {
                'e' => editProgram(),
                'a' => toggleActive(),
                _ => deleteProgram(),
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'e', child: Text('Modifier')),
                PopupMenuItem(value: 'a', child: Text(p['active'] == 1 ? 'Archiver' : 'Réactiver')),
                const PopupMenuItem(value: 'd', child: Text('Supprimer')),
              ],
            ),
        ],
      ),
      floatingActionButton: asBool(p['can_log'])
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: const Text('J\'ai fait cette séance'),
              onPressed: () async {
                if (await logWorkout(context, programId: widget.id, title: '${p['title']}')) {
                  if (context.mounted) showSnack(context, 'Séance enregistrée 💪');
                  await reload();
                }
              },
            )
          : null,
      body: AsyncStateView(
        loading: loading,
        error: error,
        data: data,
        onRetry: reload,
        builder: (context, _) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: const EdgeInsets.fromLTRB(Gaps.md, Gaps.md, Gaps.md, 88), children: content()),
        ),
      ),
    );
  }
}
