import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../services/program_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/form_dialog.dart';

// Programmes d'entraînement et séances réalisées.
// Utilisés par le membre (ses programmes) et par le coach (programmes écrits pour un client).

List<DField> _programFields([Map<String, dynamic>? p]) => [
      DField('title', 'Titre', required: true, initial: p?['title']),
      DField('goal', 'Objectif (force, perte de poids…)', initial: p?['goal']),
      DField('notes', 'Consignes', type: DType.multiline, initial: p?['notes']),
    ];

List<DField> _exerciseFields([Map<String, dynamic>? e]) => [
      DField('name', 'Exercice', required: true, initial: e?['name']),
      DField('day', 'Jour / bloc (ex. A, Lundi)', initial: e?['day']),
      DField('sets', 'Séries', type: DType.integer, max: 50, initial: e?['sets']),
      DField('reps', 'Répétitions (ex. 8-12, 45 s)', initial: e?['reps']),
      DField('load', 'Charge (ex. 40 kg)', initial: e?['load']),
      DField('rest', 'Repos (ex. 90 s)', initial: e?['rest']),
      DField('notes', 'Notes', initial: e?['notes']),
    ];

/// Saisie d'une séance réalisée (liée à un programme ou libre).
Future<bool> logWorkout(BuildContext context, {int? programId, String? title}) async {
  final r = await formDialog(
    context,
    title == null ? 'Séance libre' : 'J\'ai fait : $title',
    const [
      DField('done_on', 'Date', type: DType.date, required: true),
      DField('duration', 'Durée (minutes)', type: DType.integer, min: 1, max: 600),
      DField('rpe', 'Difficulté ressentie', type: DType.slider, min: 1, max: 10, initial: 6),
      DField('notes', 'Comment ça s\'est passé ?', type: DType.multiline),
    ],
    submit: (v) => ProgramService.logWorkout(v, programId: programId),
  );
  return r != null;
}

String exerciseLine(Map<String, dynamic> e) => [
      if (e['sets'] != null || e['reps'] != null) '${e['sets'] ?? '?'} × ${e['reps'] ?? '?'}',
      if (e['load'] != null) '${e['load']}',
      if (e['rest'] != null) 'repos ${e['rest']}',
    ].join(' · ');

/// Liste de programmes : personnels (scope=personal) ou écrits par le coach pour un client (scope=coaching).
class ProgramList extends StatefulWidget {
  final String scope;
  final int? clientId;
  final String emptyText;
  const ProgramList({super.key, required this.scope, this.clientId, required this.emptyText});
  @override
  State<ProgramList> createState() => _ProgramListState();
}

class _ProgramListState extends State<ProgramList> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      list = await ProgramService.programs(scope: widget.scope, clientId: widget.clientId);
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> create() async {
    int? id;
    await formDialog(context, widget.clientId == null ? 'Nouveau programme personnel' : 'Nouveau programme pour ce client', _programFields(), ok: 'Créer', submit: (v) async {
      id = await ProgramService.create(v, clientId: widget.clientId);
    });
    if (id != null && mounted) await open(id!);
  }

  Future<void> open(int id) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ProgramDetailPage(id)));
    load();
  }

  @override
  Widget build(BuildContext context) => AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.all(12), physics: const AlwaysScrollableScrollPhysics(), children: [
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: create, icon: const Icon(Icons.add), label: const Text('Nouveau programme'))),
            if (list.isEmpty) Empty(Icons.list_alt, widget.emptyText),
            for (final p in list)
              Card(
                child: ListTile(
                  leading: IconBadge(p['coach_id'] == null ? Icons.person_rounded : Icons.sports_rounded),
                  title: Text('${p['title']}', style: TextStyle(decoration: isTrue(p['active']) ? null : TextDecoration.lineThrough)),
                  subtitle: Text([
                    if (widget.scope == 'personal') p['coach_id'] == null ? 'Programme personnel' : 'Par ${p['coach_name'] ?? 'un coach'}',
                    if (p['goal'] != null) '${p['goal']}',
                    '${p['exercises']} exercice${num2(p['exercises']) > 1 ? 's' : ''}',
                    '${p['sessions']} séance${num2(p['sessions']) > 1 ? 's' : ''}${p['last_done'] == null ? '' : ' (dernière : ${p['last_done']})'}',
                  ].join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => open(p['id'] as int),
                ),
              ),
          ]),
        ),
      );
}

/// Mes programmes (membre / coach dans son espace personnel).
class ProgramsPage extends StatelessWidget {
  const ProgramsPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mes programmes')),
        body: const ProgramList(scope: 'personal', emptyText: 'Aucun programme.\nCréez le vôtre ou demandez-en un à votre coach (Explorer → Coachs).'),
      );
}

/// Détail d'un programme : exercices, séances réalisées, commentaires du coach.
class ProgramDetailPage extends StatefulWidget {
  final int id;
  const ProgramDetailPage(this.id, {super.key});
  @override
  State<ProgramDetailPage> createState() => _ProgramDetailPageState();
}

class _ProgramDetailPageState extends State<ProgramDetailPage> {
  Map<String, dynamic> p = {};
  bool loading = true;
  String? error;

  bool get canEdit => isTrue(p['can_edit']);
  List<Map<String, dynamic>> listOf(String k) => ((p[k] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      p = await ProgramService.program(widget.id);
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> editProgram() async {
    final r = await formDialog(context, 'Modifier le programme', _programFields(p), submit: (v) => ProgramService.update(widget.id, {...v, 'active': p['active']}));
    if (r != null) load();
  }

  Future<void> toggleActive() async {
    if (await attempt(context, () => ProgramService.update(widget.id, {'title': p['title'], 'goal': p['goal'], 'notes': p['notes'], 'active': !isTrue(p['active'])}))) load();
  }

  Future<void> deleteProgram() async {
    if (!await confirm(context, 'Supprimer « ${p['title']} » ?', body: 'Les exercices seront supprimés. Les séances déjà réalisées restent dans l\'historique.', ok: 'Supprimer')) return;
    if (!mounted) return;
    if (await attempt(context, () => ProgramService.delete(widget.id)) && mounted) Navigator.pop(context);
  }

  Future<void> exercise([Map<String, dynamic>? e]) async {
    final r = await formDialog(context, e == null ? 'Ajouter un exercice' : 'Modifier l\'exercice', _exerciseFields(e),
        submit: (v) => e == null ? ProgramService.addExercise(widget.id, v) : ProgramService.updateExercise(e['id'] as int, {...v, 'position': e['position']}));
    if (r != null) load();
  }

  Future<void> deleteExercise(Map<String, dynamic> e) async {
    if (await attempt(context, () => ProgramService.deleteExercise(e['id'] as int))) load();
  }

  Future<void> comment(Map<String, dynamic> w) async {
    final r = await formDialog(context, 'Commentaire pour votre client', [DField('comment', 'Retour, conseils…', type: DType.multiline, initial: w['coach_comment'])],
        ok: 'Envoyer', submit: (v) => ProgramService.comment(w['id'] as int, v['comment'] as String?));
    if (r != null) load();
  }

  @override
  Widget build(BuildContext context) {
    final items = listOf('items'), workouts = listOf('workouts');
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final e in items) {
      groups.putIfAbsent('${e['day'] ?? ''}', () => []).add(e);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(loading ? 'Programme' : '${p['title']}'),
        actions: [
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) { 'e' => editProgram(), 'a' => toggleActive(), _ => deleteProgram() },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'e', child: Text('Modifier')),
                PopupMenuItem(value: 'a', child: Text(isTrue(p['active']) ? 'Archiver' : 'Réactiver')),
                const PopupMenuItem(value: 'd', child: Text('Supprimer')),
              ],
            ),
        ],
      ),
      floatingActionButton: isTrue(p['can_log'])
          ? FloatingActionButton.extended(
              icon: const Icon(Icons.check),
              label: const Text('J\'ai fait cette séance'),
              onPressed: () async {
                if (await logWorkout(context, programId: widget.id, title: '${p['title']}')) {
                  if (context.mounted) snack(context, 'Séance enregistrée 💪');
                  load();
                }
              },
            )
          : null,
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 88), children: [
            Card(
              child: ListTile(
                leading: IconBadge(p['coach_id'] == null ? Icons.person_rounded : Icons.sports_rounded),
                title: Text(p['coach_id'] == null ? 'Programme personnel' : 'Coach : ${p['coach_name'] ?? '—'}'),
                subtitle: Text([
                  if (!isTrue(p['can_log'])) 'Client : ${p['client_name']}',
                  if (p['goal'] != null) 'Objectif : ${p['goal']}',
                  if (!isTrue(p['active'])) 'Archivé',
                  if (p['notes'] != null) '${p['notes']}',
                ].join('\n')),
              ),
            ),
            Row(children: [
              Expanded(child: sectionTitle(context, 'Exercices')),
              if (canEdit) TextButton.icon(onPressed: () => exercise(), icon: const Icon(Icons.add), label: const Text('Ajouter')),
            ]),
            if (items.isEmpty) Card(child: Empty(Icons.fitness_center, canEdit ? 'Ajoutez le premier exercice.' : 'Aucun exercice pour le moment.')),
            for (final g in groups.entries) ...[
              if (g.key.isNotEmpty) Padding(padding: const EdgeInsets.fromLTRB(4, 8, 4, 2), child: Text('Bloc ${g.key}', style: Theme.of(context).textTheme.labelLarge)),
              for (final e in g.value)
                Card(
                  child: ListTile(
                    title: Text('${e['name']}'),
                    subtitle: Text([exerciseLine(e), if (e['notes'] != null) '${e['notes']}'].where((s) => s.isNotEmpty).join('\n')),
                    onTap: canEdit ? () => exercise(e) : null,
                    trailing: canEdit ? IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: () => deleteExercise(e)) : null,
                  ),
                ),
            ],
            sectionTitle(context, 'Séances réalisées'),
            if (workouts.isEmpty) const Card(child: Empty(Icons.history, 'Aucune séance enregistrée.')),
            for (final w in workouts) WorkoutCard(w, onComment: isTrue(p['can_comment']) ? () => comment(w) : null),
          ]),
        ),
      ),
    );
  }
}

/// Carte d'une séance réalisée, avec le commentaire éventuel du coach.
class WorkoutCard extends StatelessWidget {
  final Map<String, dynamic> w;
  final VoidCallback? onComment, onDelete;
  const WorkoutCard(this.w, {super.key, this.onComment, this.onDelete});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 8),
            Expanded(child: Text('${w['done_on']}${w['program_title'] == null ? '' : ' · ${w['program_title']}'}', style: const TextStyle(fontWeight: FontWeight.w600))),
            if (onDelete != null) IconButton(tooltip: 'Supprimer', icon: const Icon(Icons.delete_outline), onPressed: onDelete),
          ]),
          Text([if (w['duration'] != null) '${w['duration']} min', if (w['rpe'] != null) 'difficulté ${w['rpe']}/10'].join(' · ')),
          if (w['notes'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${w['notes']}')),
          if (w['coach_comment'] != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.sports, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('${w['coach_comment']}')),
              ]),
            ),
          if (onComment != null)
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onComment, icon: const Icon(Icons.rate_review), label: Text(w['coach_comment'] == null ? 'Commenter' : 'Modifier le commentaire'))),
        ]),
      ),
    );
  }
}

/// Liste des séances d'un membre (les siennes, ou celles d'un client pour son coach).
class WorkoutList extends StatefulWidget {
  final int? userId; // null = moi
  const WorkoutList({super.key, this.userId});
  @override
  State<WorkoutList> createState() => WorkoutListState();
}

class WorkoutListState extends State<WorkoutList> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;
  String? error;
  bool get mine => widget.userId == null || widget.userId == Api.myId;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      list = await ProgramService.workouts(userId: widget.userId);
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> comment(Map<String, dynamic> w) async {
    final r = await formDialog(context, 'Commentaire', [DField('comment', 'Retour, conseils…', type: DType.multiline, initial: w['coach_comment'])],
        ok: 'Envoyer', submit: (v) => ProgramService.comment(w['id'] as int, v['comment'] as String?));
    if (r != null) load();
  }

  Future<void> remove(Map<String, dynamic> w) async {
    if (!await confirm(context, 'Supprimer cette séance ?', ok: 'Supprimer')) return;
    if (mounted && await attempt(context, () => ProgramService.deleteWorkout(w['id'] as int))) load();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final week = list.where((w) => (DateTime.tryParse('${w['done_on']}') ?? DateTime(2000)).isAfter(weekStart.subtract(const Duration(seconds: 1)))).length;
    final month = todayIso().substring(0, 7);
    final minutes = list.where((w) => '${w['done_on']}'.startsWith(month)).fold<double>(0, (s, w) => s + num2(w['duration']));
    return AsyncBody(
      loading: loading,
      error: error,
      onRetry: load,
      builder: () => RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 88), physics: const AlwaysScrollableScrollPhysics(), children: [
          Row(children: [
            Expanded(child: kpiCard(context, Icons.date_range, 'Cette semaine', '$week')),
            Expanded(child: kpiCard(context, Icons.timer, 'Minutes (mois)', minutes.toStringAsFixed(0))),
            Expanded(child: kpiCard(context, Icons.emoji_events, 'Total', '${list.length}')),
          ]),
          sectionTitle(context, 'Historique'),
          if (list.isEmpty) Card(child: Empty(Icons.history, mine ? 'Aucune séance enregistrée.\nAppuyez sur « Séance » pour noter votre entraînement.' : 'Aucune séance sur vos programmes pour le moment.')),
          for (final w in list)
            WorkoutCard(w, onDelete: mine ? () => remove(w) : null, onComment: !mine && w['coach_id'] == Api.myId ? () => comment(w) : null),
        ]),
      ),
    );
  }
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
      appBar: AppBar(title: const Text('Mes séances')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Séance'),
        onPressed: () async {
          if (await logWorkout(context)) key.currentState?.load();
        },
      ),
      body: WorkoutList(key: key),
    );
  }
}
