import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../models/module.dart';
import '../services/user_service.dart';
import '../widgets/common_widgets.dart';
import 'crud_screen.dart';
import 'member_screens.dart';
import 'stripe_payments_screen.dart';

/// One entry point for access, offline requests and verified online billing.
class MembershipPage extends StatefulWidget {
  const MembershipPage({super.key});
  @override
  State<MembershipPage> createState() => _MembershipPageState();
}

class _MembershipPageState extends State<MembershipPage> {
  bool _loading = true, _busy = false;
  String? _error;
  List<Json> _requests = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Api.refreshMe();
      final requests = await UserService.myRequests();
      if (!mounted) return;
      _requests = requests;
      _error = null;
    } catch (_) {
      _error = 'Impossible de mettre à jour votre abonnement. Réessayez.';
    } finally {
      if (mounted)
        setState(() {
          _loading = false;
          _busy = false;
        });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) await _load();
  }

  Widget _link(IconData icon, String title, String subtitle, Widget page) =>
      Card(
        child: ListTile(
          leading: IconBadge(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => _open(page),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final me = Api.user!;
    final pending = _requests.where((r) => r['status'] == 'pending');
    final end = DateTime.tryParse(me.subEnd ?? '');
    final now = DateTime.now();
    final remaining = end
        ?.difference(DateTime(now.year, now.month, now.day))
        .inDays;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon abonnement'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _busy ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Chargement de votre abonnement',
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (_busy) const LinearProgressIndicator(),
                      if (_error != null)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_error!),
                                TextButton(
                                  onPressed: _busy ? null : _load,
                                  child: const Text('Réessayer'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      HeroCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'VOTRE ADHÉSION IRONFIT',
                              style: TextStyle(
                                color: AppColors.amber,
                                letterSpacing: 1.3,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              me.planName ?? 'Aucune formule',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(color: Colors.white),
                            ),
                            const SizedBox(height: 12),
                            StatusPill(
                              me.hasActiveSubscription
                                  ? 'Accès actif'
                                  : 'Accès inactif',
                              color: me.hasActiveSubscription
                                  ? AppColors.amber
                                  : const Color(0xFFFF8A80),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              end == null
                                  ? 'Choisissez une formule pour rejoindre la salle.'
                                  : 'Accès payé jusqu’au ${me.subEnd}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            if (me.hasActiveSubscription && remaining != null)
                              Text(
                                remaining == 0
                                    ? 'Expire aujourd’hui'
                                    : '$remaining jour(s) avant expiration',
                                style: const TextStyle(color: Colors.white70),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => _open(const ExplorePage()),
                        icon: const Icon(Icons.card_membership_outlined),
                        label: Text(
                          me.planId == null
                              ? 'Découvrir les formules'
                              : 'Renouveler ou choisir une formule',
                        ),
                      ),
                      const SectionHeader('Demandes à l’accueil'),
                      if (_error == null && pending.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('Aucune demande en attente.'),
                        ),
                      for (final request in pending)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${request['plan_name']}',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const Text(
                                  'En attente de règlement et de validation à l’accueil.',
                                ),
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () async {
                                          if (!await confirm(
                                            context,
                                            'Annuler cette demande ?',
                                          ))
                                            return;
                                          if (!mounted || !context.mounted)
                                            return;
                                          setState(() => _busy = true);
                                          final ok = await attempt(
                                            context,
                                            () => UserService.cancelRequest(
                                              request['id'] as int,
                                            ),
                                          );
                                          if (!mounted) return;
                                          setState(() => _busy = false);
                                          if (ok) await _load();
                                        },
                                  child: const Text('Annuler la demande'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SectionHeader('Paiements et factures'),
                      _link(
                        Icons.lock_outline,
                        'Paiements en ligne',
                        'Confirmation Stripe, factures et gestion du renouvellement automatique · mode test',
                        const StripePaymentsPage(),
                      ),
                      _link(
                        Icons.receipt_long_outlined,
                        'Tous mes règlements',
                        'Historique des paiements enregistrés par la salle et en ligne',
                        CrudPage(moduleById('payments')),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'La date d’accès et le renouvellement automatique sont distincts. Gérez votre abonnement Stripe depuis « Paiements en ligne ».',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
