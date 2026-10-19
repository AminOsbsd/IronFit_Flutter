import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/widgets/feedback.dart';
import '../member/progress.dart';
import '../programs/program_list.dart';
import '../programs/workouts.dart';

/// Suivi d'un client par son coach : programmes, séances, progression.
class ClientDetailPage extends StatelessWidget {
  final Json link;
  const ClientDetailPage(this.link, {super.key});

  int get clientId => link['client_id'] as int;

  Future<void> end(BuildContext context) async {
    final ok = await confirm(
      context,
      'Arrêter le suivi de ${link['client_name']} ?',
      body: 'Vous n\'aurez plus accès à ses données ni aux programmes que vous lui avez écrits.',
      ok: 'Arrêter',
    );
    if (!ok || !context.mounted) return;
    if (await attempt(context, () => Api.call('POST', 'coaching/${link['id']}/end')) && context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Scaffold(
      appBar: AppBar(
        title: Text('${link['client_name']}'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Plus d\'actions',
            onSelected: (_) => end(context),
            itemBuilder: (_) => const [PopupMenuItem(value: 'end', child: Text('Arrêter le suivi'))],
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Programmes'),
            Tab(text: 'Séances'),
            Tab(text: 'Progression'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (link['client_phone'] != null)
            ListTile(dense: true, leading: const Icon(Icons.phone), title: Text('${link['client_phone']}')),
          Expanded(
            child: TabBarView(
              children: [
                ProgramList(
                  scope: 'coaching',
                  clientId: clientId,
                  emptyText: 'Aucun programme pour ce client.\nCréez-en un pour commencer le suivi.',
                ),
                WorkoutList(userId: clientId),
                ProgressView(memberId: clientId),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
