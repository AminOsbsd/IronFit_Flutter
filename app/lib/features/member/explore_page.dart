import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../coaching/coaches_tab.dart';
import 'subscription.dart';

typedef ExploreData = ({List<Json> plans, List<Json> promos, List<Json> products, List<Json> ann, List<Json> reqs});

/// Disponibilité d'un produit selon son stock.
String stockLabel(Object? stock) {
  final s = toDouble(stock);
  return s <= 0 ? 'Rupture' : (s <= 5 ? 'Stock limité' : 'Disponible');
}

/// Explorer : tarifs (avec demande d'abonnement), coachs, offres, boutique, annonces.
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with AsyncLoadMixin<ExplorePage, ExploreData> {
  @override
  Future<ExploreData> fetch() async {
    final (plans, promos, products, ann, reqs) = await (
      Api.listOrEmpty('plans'),
      Api.listOrEmpty('promos'),
      Api.listOrEmpty('products'),
      Api.listOrEmpty('announcements'),
      Api.listOrEmpty('requests'),
    ).wait;
    return (plans: plans, promos: promos, products: products, ann: ann, reqs: reqs);
  }

  Future<void> choose(Json p) async {
    final ok = await confirm(
      context,
      'Demander « ${p['name']} » ?',
      body:
          '${p['price']} DT · ${p['duration'] ?? ''}\n'
          'L\'abonnement sera activé par l\'administrateur après paiement à l\'accueil.',
      ok: 'Envoyer la demande',
    );
    if (!ok || !mounted) return;
    final sent = await attempt(
      context,
      () => Api.call('POST', 'requests', {'plan_id': p['id']}),
      success: 'Demande envoyée ✓',
    );
    if (sent) await reload();
  }

  Widget plansTab(ExploreData d) {
    if (d.plans.isEmpty) {
      return const EmptyState(icon: Icons.credit_card_off, text: 'Aucun tarif disponible pour le moment');
    }
    final pending = d.reqs.where((r) => r['status'] == 'pending').toList();
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: Gaps.page,
      children: [
        for (final p in d.plans)
          Card(
            child: Padding(
              padding: Gaps.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('${p['name']}', style: t.titleMedium)),
                      if (Api.me?['plan_id'] == p['id']) const Chip(label: Text('Mon offre')),
                    ],
                  ),
                  Text('${p['price']} DT', style: t.headlineMedium?.copyWith(color: cs.primary)),
                  Text('${p['duration'] ?? ''}'),
                  if ((p['descr'] ?? '') != '')
                    Padding(
                      padding: const EdgeInsets.only(top: Gaps.xs),
                      child: Text('${p['descr']}'),
                    ),
                  Gaps.h12,
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: pending.isNotEmpty ? null : () => choose(p),
                      child: Text(
                        pending.any((r) => r['plan_id'] == p['id'])
                            ? 'Demande envoyée'
                            : (Api.me?['plan_id'] == p['id'] ? 'Renouveler' : 'Choisir'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget promosTab(ExploreData d) {
    if (d.promos.isEmpty) return const EmptyState(icon: Icons.local_offer_outlined, text: 'Aucune offre en ce moment');
    final cs = Theme.of(context).colorScheme;
    final small = Theme.of(context).textTheme.labelSmall;
    return ListView(
      padding: Gaps.page,
      children: [
        for (final p in d.promos)
          Builder(
            builder: (_) {
              final expired = isPast(p['until']);
              final fg = expired ? cs.onSurfaceVariant : cs.onPrimary;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: expired ? cs.surfaceContainerHighest : cs.primary,
                    foregroundColor: fg,
                    child: Text('-${p['discount'] ?? 0}%', style: small?.copyWith(color: fg)),
                  ),
                  title: Text('${p['title']}'),
                  subtitle: Text(
                    '${p['descr'] ?? ''}\n${expired ? 'Expirée' : 'Valable jusqu\'au ${p['until'] ?? '—'}'}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget shopTab(ExploreData d) {
    if (d.products.isEmpty) return const EmptyState(icon: Icons.storefront, text: 'La boutique est vide');
    final t = Theme.of(context).textTheme;
    final extent = MediaQuery.textScalerOf(context).scale(110) + 30;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(Gaps.sm),
          child: Text('Achat directement à l\'accueil de la salle.', style: t.bodySmall),
        ),
        Expanded(
          child: GridView(
            padding: Gaps.page,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220,
              mainAxisExtent: extent,
              mainAxisSpacing: Gaps.sm,
              crossAxisSpacing: Gaps.sm,
            ),
            children: [
              for (final p in d.products)
                Card(
                  child: Padding(
                    padding: Gaps.page,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ExcludeSemantics(child: Icon(Icons.shopping_bag_outlined, size: 30)),
                        Text(
                          '${p['name']}',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSmall,
                        ),
                        Text(
                          '${p['price']} DT',
                          style: t.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                        ),
                        Text(stockLabel(p['stock']), style: t.bodySmall),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget annTab(ExploreData d) => d.ann.isEmpty
      ? const EmptyState(icon: Icons.campaign_outlined, text: 'Aucune annonce')
      : ListView(
          padding: Gaps.page,
          children: [
            for (final a in d.ann)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign),
                  title: Text('${a['title']}'),
                  subtitle: Text('${a['posted_on'] ?? ''}\n${a['body'] ?? ''}'),
                  isThreeLine: true,
                ),
              ),
          ],
        );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Explorer'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Tarifs'),
              Tab(text: 'Coachs'),
              Tab(text: 'Offres'),
              Tab(text: 'Boutique'),
              Tab(text: 'Annonces'),
            ],
          ),
          actions: [RefreshButton(onPressed: reload)],
        ),
        body: AsyncStateView(
          loading: loading,
          error: error,
          data: data,
          onRetry: reload,
          builder: (context, d) =>
              TabBarView(children: [plansTab(d), const CoachesTab(), promosTab(d), shopTab(d), annTab(d)]),
        ),
      ),
    );
  }
}
