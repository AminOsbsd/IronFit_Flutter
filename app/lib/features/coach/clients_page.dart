import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/kpi.dart';
import '../member/subscription.dart';
import 'client_detail_page.dart';

/// Résumé de l'abonnement d'un client, vu par son coach.
String clientSubscription(Object? subEnd) {
  if (subEnd == null) return 'Sans abonnement';
  return isPast(subEnd) ? 'Abonnement expiré' : 'Abonné jusqu\'au $subEnd';
}

/// Mes clients : demandes en attente et clients suivis.
class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> with AsyncLoadMixin<ClientsPage, List<Json>> {
  String q = '';

  @override
  Future<List<Json>> fetch() => Api.list('coaching/clients');

  Future<void> answer(Json l, bool accept) async {
    if (await attempt(context, () => Api.call('POST', 'coaching/${l['id']}/${accept ? 'accept' : 'decline'}'))) {
      await reload();
    }
  }

  Future<void> open(Json l) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ClientDetailPage(l)));
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes clients'),
        actions: [RefreshButton(onPressed: reload)],
      ),
      body: AsyncStateView(
        loading: loading,
        error: error,
        data: data,
        onRetry: reload,
        builder: (context, links) {
          final pending = links.where((l) => l['status'] == 'pending').toList();
          final active = links
              .where((l) => l['status'] == 'active' && '${l['client_name']}'.toLowerCase().contains(q.toLowerCase()))
              .toList();
          return RefreshIndicator(
            onRefresh: reload,
            child: ListView(
              padding: Gaps.page,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (pending.isNotEmpty) ...[
                  SectionTitle('Demandes en attente (${pending.length})'),
                  for (final l in pending)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.person_add),
                        title: Text('${l['client_name']}'),
                        subtitle: Text('@${l['client_login']}'),
                        trailing: Wrap(
                          spacing: Gaps.xs,
                          children: [
                            IconButton(
                              tooltip: 'Refuser ${l['client_name']}',
                              onPressed: () => answer(l, false),
                              icon: const Icon(Icons.close),
                            ),
                            IconButton.filled(
                              tooltip: 'Accepter ${l['client_name']}',
                              onPressed: () => answer(l, true),
                              icon: const Icon(Icons.check),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                const SectionTitle('Clients suivis'),
                TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Rechercher un client',
                    isDense: true,
                  ),
                  onChanged: (s) => setState(() => q = s),
                ),
                Gaps.h8,
                if (active.isEmpty)
                  Card(
                    child: EmptyState(
                      icon: Icons.groups,
                      text: q.isEmpty
                          ? 'Aucun client pour le moment.\nLes membres peuvent vous choisir depuis Explorer → Coachs, '
                                'ou l\'administration peut vous en attribuer.'
                          : 'Aucun résultat',
                    ),
                  ),
                for (final l in active)
                  Card(
                    child: ListTile(
                      leading: InitialAvatar(l['client_name']),
                      title: Text('${l['client_name'] ?? ''}'),
                      subtitle: Text(
                        '${clientSubscription(l['client_sub_end'])} · Dernière séance : ${l['last_workout'] ?? '—'}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => open(l),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
