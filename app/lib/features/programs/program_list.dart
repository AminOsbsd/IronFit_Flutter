import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/form_dialog.dart';
import 'program_detail_page.dart';

// Programmes d'entraînement : utilisés par le membre (ses programmes) et par le coach (programmes d'un client).

List<DField> programFields([Json? p]) => [
  DField('title', 'Titre', required: true, initial: p?['title']),
  DField('goal', 'Objectif (force, perte de poids…)', initial: p?['goal']),
  DField('notes', 'Consignes', type: DType.multiline, initial: p?['notes']),
];

/// Ligne de résumé d'un programme dans une liste.
String programSubtitle(Json p, {required bool showAuthor}) => [
  if (showAuthor) p['coach_id'] == null ? 'Programme personnel' : 'Par ${p['coach_name'] ?? 'un coach'}',
  if (p['goal'] != null) '${p['goal']}',
  plural(toInt(p['exercises']), 'exercice'),
  '${plural(toInt(p['sessions']), 'séance')}${p['last_done'] == null ? '' : ' (dernière : ${p['last_done']})'}',
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

class _ProgramListState extends State<ProgramList> with AsyncLoadMixin<ProgramList, List<Json>> {
  @override
  Future<List<Json>> fetch() =>
      Api.list(Api.withQuery('programs', {'scope': widget.scope, 'client_id': widget.clientId}));

  Future<void> create() async {
    int? id;
    await formDialog(
      context,
      widget.clientId == null ? 'Nouveau programme personnel' : 'Nouveau programme pour ce client',
      programFields(),
      ok: 'Créer',
      submit: (v) async {
        final r = await Api.call('POST', 'programs', {...v, 'client_id': widget.clientId});
        id = (r as Map)['id'] as int;
      },
    );
    final created = id;
    if (created != null && mounted) await open(created);
  }

  Future<void> open(int id) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ProgramDetailPage(id)));
    await reload();
  }

  @override
  Widget build(BuildContext context) => AsyncStateView(
    loading: loading,
    error: error,
    data: data,
    onRetry: reload,
    builder: (context, list) => RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: Gaps.page,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: create,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau programme'),
            ),
          ),
          if (list.isEmpty) EmptyState(icon: Icons.list_alt, text: widget.emptyText),
          for (final p in list)
            Card(
              child: ListTile(
                leading: ExcludeSemantics(
                  child: CircleAvatar(child: Icon(p['coach_id'] == null ? Icons.person : Icons.sports)),
                ),
                title: Text(
                  '${p['title']}',
                  style: TextStyle(decoration: p['active'] == 0 ? TextDecoration.lineThrough : null),
                  semanticsLabel: '${p['title']}${p['active'] == 0 ? ' (archivé)' : ''}',
                ),
                subtitle: Text(programSubtitle(p, showAuthor: widget.scope == 'personal')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => open(p['id'] as int),
              ),
            ),
        ],
      ),
    ),
  );
}

/// Mes programmes (membre / coach dans son espace personnel).
class ProgramsPage extends StatelessWidget {
  const ProgramsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mes programmes')),
    body: const ProgramList(
      scope: 'personal',
      emptyText: 'Aucun programme.\nCréez le vôtre ou demandez-en un à votre coach (Explorer → Coachs).',
    ),
  );
}
