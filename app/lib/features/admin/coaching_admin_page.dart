import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/api/refs.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';

/// Supervision des relations coach ↔ client (admin) : filtre par statut, attribution, fin de suivi.
class CoachingAdminPage extends StatefulWidget {
  const CoachingAdminPage({super.key});

  @override
  State<CoachingAdminPage> createState() => _CoachingAdminPageState();
}

class _CoachingAdminPageState extends State<CoachingAdminPage> with AsyncLoadMixin<CoachingAdminPage, List<Json>> {
  static const statuses = {
    '': 'Tous',
    'active': 'Actifs',
    'pending': 'En attente',
    'ended': 'Terminés',
    'declined': 'Refusés',
  };
  String status = '';

  @override
  Future<List<Json>> fetch() => Api.list(Api.withQuery('coaching', {'status': status}));

  void filter(String s) {
    setState(() {
      status = s;
      data = null; // affiche l'indicateur pendant le changement de filtre
    });
    reload();
  }

  Future<void> assign() async {
    await Refs.load();
    final coaches = Refs.data['coaches'] ?? const <Json>[], members = Refs.data['members'] ?? const <Json>[];
    if (!mounted) return;
    Object? coach, client;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Attribuer un coach'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Object?>(
                initialValue: coach,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Coach'),
                items: [
                  for (final c in coaches)
                    DropdownMenuItem(value: c['id'], child: Text('${c['name']} · ${c['specialty'] ?? ''}')),
                ],
                onChanged: (x) => set(() => coach = x),
              ),
              Gaps.h12,
              DropdownButtonFormField<Object?>(
                initialValue: client,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Membre'),
                items: [
                  for (final m in members.where((m) => m['id'] != coach && m['active'] != 0))
                    DropdownMenuItem(value: m['id'], child: Text('${m['name']} (@${m['login']})')),
                ],
                onChanged: (x) => set(() => client = x),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
            FilledButton(
              onPressed: () => Navigator.pop(d, coach != null && client != null),
              child: const Text('Attribuer'),
            ),
          ],
        ),
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    final done = await attempt(
      context,
      () => Api.call('POST', 'coaching/assign', {'coach_id': coach, 'client_id': client}),
      success: 'Coach attribué ✓',
    );
    if (done) await reload();
  }

  Future<void> end(Json l) async {
    final ok = await confirm(
      context,
      'Mettre fin au suivi ?',
      body: '${l['coach_name']} → ${l['client_name']}',
      ok: 'Terminer',
    );
    if (ok && mounted && await attempt(context, () => Api.call('POST', 'coaching/${l['id']}/end'))) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final chipsHeight = MediaQuery.textScalerOf(context).scale(36) + 2 * Gaps.sm;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Suivis coaching'),
        actions: [RefreshButton(onPressed: reload)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: assign,
        icon: const Icon(Icons.person_add),
        label: const Text('Attribuer'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: chipsHeight,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.xs),
              children: [
                for (final e in statuses.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: Gaps.sm),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: status == e.key,
                      onSelected: (_) => filter(e.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncStateView(
              loading: loading,
              error: error,
              data: data,
              onRetry: reload,
              builder: (context, list) => list.isEmpty
                  ? const EmptyState(icon: Icons.sports, text: 'Aucune relation de coaching')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(Gaps.md, 0, Gaps.md, 88),
                      children: [
                        for (final l in list)
                          Card(
                            child: ListTile(
                              leading: Icon(switch (l['status']) {
                                'active' => Icons.verified,
                                'pending' => Icons.hourglass_top,
                                _ => Icons.history,
                              }),
                              title: Text('${l['coach_name']} → ${l['client_name']}'),
                              subtitle: Text(
                                '${statuses[l['status']] ?? l['status']} · depuis le ${datePart(l['updated'])}',
                              ),
                              trailing: l['status'] == 'active' || l['status'] == 'pending'
                                  ? TextButton(onPressed: () => end(l), child: const Text('Terminer'))
                                  : null,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
