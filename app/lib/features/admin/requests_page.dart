import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';

/// Demandes d'abonnement envoyées par les membres : valider (paiement reçu) ou refuser.
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> with AsyncLoadMixin<RequestsPage, List<Json>> {
  @override
  Future<List<Json>> fetch() => Api.list('requests');

  Future<void> approve(Json r) async {
    final method = await pickPaymentMethod(context, 'Paiement reçu de ${r['member_name']} (${r['price']} DT)');
    if (method == null || !mounted) return;
    final ok = await attempt(
      context,
      () => Api.call('POST', 'requests/${r['id']}/approve', {'method': method}),
      success: 'Abonnement activé, paiement enregistré ✓',
    );
    if (ok) await reload();
  }

  Future<void> reject(Json r) async {
    if (!await confirm(context, 'Refuser la demande de ${r['member_name']} ?', ok: 'Refuser')) return;
    if (mounted && await attempt(context, () => Api.call('POST', 'requests/${r['id']}/reject'))) await reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Demandes d\'abonnement'),
      actions: [RefreshButton(onPressed: reload)],
    ),
    body: AsyncStateView(
      loading: loading,
      error: error,
      data: data,
      onRetry: reload,
      builder: (context, list) => list.isEmpty
          ? const EmptyState(icon: Icons.assignment_turned_in, text: 'Aucune demande en attente')
          : ListView(
              padding: Gaps.page,
              children: [
                for (final r in list)
                  Card(
                    child: Padding(
                      padding: Gaps.card,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['member_name']}', style: Theme.of(context).textTheme.titleMedium),
                          Text('${r['plan_name']} — ${r['price']} DT · demandé le ${datePart(r['created'])}'),
                          Gaps.h8,
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: Gaps.sm,
                            children: [
                              TextButton(onPressed: () => reject(r), child: const Text('Refuser')),
                              FilledButton(onPressed: () => approve(r), child: const Text('Valider (payé)')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}
