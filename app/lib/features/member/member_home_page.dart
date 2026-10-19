import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/api/refs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/kpi.dart';
import '../programs/program_detail_page.dart';
import '../shell/notification_bell.dart';
import 'subscription.dart';

/// Données de l'accueil membre.
class MemberDashboard {
  final List<Json> classes, announcements, promos, requests, measures, programs, workouts;
  const MemberDashboard({
    required this.classes,
    required this.announcements,
    required this.promos,
    required this.requests,
    required this.measures,
    required this.programs,
    required this.workouts,
  });

  /// Cours réservés, du plus proche au plus lointain dans la semaine.
  List<Json> upcoming([DateTime? now]) => classes.where((c) => asBool(c['mine'])).toList()
    ..sort((a, b) {
      final ka = daysAhead(toInt(a['day']), now), kb = daysAhead(toInt(b['day']), now);
      return ka != kb ? ka.compareTo(kb) : '${a['time']}'.compareTo('${b['time']}');
    });

  /// Séances enregistrées sur les 7 derniers jours.
  int workoutsLastWeek([DateTime? now]) {
    final ago7 = (now ?? DateTime.now()).subtract(const Duration(days: 7));
    return workouts.where((w) => (DateTime.tryParse('${w['done_on']}') ?? DateTime(2000)).isAfter(ago7)).length;
  }

  /// Dernier poids mesuré, ou `—`.
  String latestWeight() {
    final withWeight = measures.where((m) => m['weight'] != null).toList()
      ..sort((a, b) => '${b['measured_on']}'.compareTo('${a['measured_on']}'));
    return withWeight.isEmpty ? '—' : '${withWeight.first['weight']} kg';
  }
}

// Écrans de l'espace membre : utilisés par les athlètes et par les coachs dans « Mon entraînement ».

/// Accueil membre : carte membre, abonnement, programmes, prochains cours, annonces, offre du moment.
class MemberHome extends StatefulWidget {
  /// Ouvre un autre onglet de la barre de navigation (1 = Planning, 2 = Explorer, 3 = Mon espace).
  final ValueChanged<int> goTab;
  const MemberHome({super.key, required this.goTab});

  @override
  State<MemberHome> createState() => _MemberHomeState();
}

class _MemberHomeState extends State<MemberHome> with AsyncLoadMixin<MemberHome, MemberDashboard> {
  @override
  Future<MemberDashboard> fetch() async {
    await Api.refreshMe();
    final r = await Future.wait([
      for (final ep in [
        'classes',
        'announcements',
        'promos',
        'requests',
        'measures',
        'programs?scope=personal',
        'workouts?limit=50',
      ])
        Api.listOrEmpty(ep),
      Refs.load().then((_) => <Json>[]),
    ]);
    unawaited(Api.refreshUnread());
    return MemberDashboard(
      classes: r[0],
      announcements: r[1],
      promos: r[2],
      requests: r[3],
      measures: r[4],
      programs: r[5],
      workouts: r[6],
    );
  }

  Future<void> cancelRequest(Object? id) async {
    if (await attempt(context, () => Api.call('POST', 'requests/$id/cancel'))) await reload();
  }

  Future<void> openProgram(Object? id) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ProgramDetailPage(id as int)));
    await reload();
  }

  List<Widget> content(MemberDashboard d) {
    final me = Api.me!;
    final cs = Theme.of(context).colorScheme;
    final sub = SubscriptionStatus.of(me['sub_end'] as String?);
    final pending = d.requests.where((r) => r['status'] == 'pending').toList();
    final mine = d.upcoming();
    final offers = d.promos.where((p) => !isPast(p['until'])).toList();
    final activePrograms = d.programs.where((p) => p['active'] == 1).toList();

    return [
      MemberCard(me: me, status: sub),
      if (pending.isNotEmpty)
        Card(
          margin: const EdgeInsets.only(top: Gaps.md),
          child: ListTile(
            leading: const Icon(Icons.hourglass_top),
            title: Text('Demande en attente : ${pending.first['plan_name']}'),
            subtitle: const Text('Réglez à l\'accueil : l\'abonnement sera activé par l\'administrateur.'),
            trailing: TextButton(onPressed: () => cancelRequest(pending.first['id']), child: const Text('Annuler')),
          ),
        )
      else if (!sub.active)
        Card(
          margin: const EdgeInsets.only(top: Gaps.md),
          color: cs.tertiaryContainer,
          child: ListTile(
            leading: const Icon(Icons.card_membership),
            title: Text(sub.hasPlan ? 'Votre abonnement a expiré' : 'Pas encore d\'abonnement'),
            subtitle: const Text('Choisissez une formule pour réserver vos séances.'),
            trailing: FilledButton(onPressed: () => widget.goTab(2), child: const Text('Choisir')),
          ),
        ),
      Gaps.h12,
      KpiGrid(
        columns: 3,
        children: [
          KpiCard(icon: Icons.local_fire_department, label: 'Séances (7 j)', value: '${d.workoutsLastWeek()}'),
          KpiCard(icon: Icons.event_available, label: 'Réservations', value: '${mine.length}'),
          KpiCard(icon: Icons.monitor_weight, label: 'Poids', value: d.latestWeight()),
        ],
      ),
      const SectionTitle('Mes programmes'),
      if (activePrograms.isEmpty)
        Card(
          child: EmptyState(
            icon: Icons.list_alt,
            text: 'Aucun programme actif.',
            cta: 'Créer ou trouver un coach',
            onTap: () => widget.goTab(3),
          ),
        )
      else
        for (final p in activePrograms.take(3))
          Card(
            child: ListTile(
              leading: Icon(p['coach_id'] == null ? Icons.person : Icons.sports),
              title: Text('${p['title']}'),
              subtitle: Text(
                '${p['coach_id'] == null ? 'Personnel' : 'Par ${p['coach_name']}'} · '
                '${plural(toInt(p['sessions']), 'séance')}'
                '${p['last_done'] == null ? '' : ' · dernière ${p['last_done']}'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => openProgram(p['id']),
            ),
          ),
      const SectionTitle('Mes prochains cours'),
      if (mine.isEmpty)
        Card(
          child: EmptyState(
            icon: Icons.event,
            text: 'Aucun cours réservé.',
            cta: 'Voir le planning',
            onTap: () => widget.goTab(1),
          ),
        )
      else
        for (final c in mine.take(3))
          Card(
            child: ListTile(
              leading: ExcludeSemantics(child: Icon(Icons.check_circle, color: AppColors.of(context).success)),
              title: Text('${c['title']}'),
              subtitle: Text('${dayLabel(toInt(c['day']))} · ${c['time']} · ${c['coach_name'] ?? '—'}'),
            ),
          ),
      if (d.announcements.isNotEmpty) const SectionTitle('Annonces'),
      for (final a in d.announcements.take(2))
        Card(
          child: ListTile(
            leading: const Icon(Icons.campaign),
            title: Text('${a['title']}'),
            subtitle: Text('${a['body'] ?? ''}'),
          ),
        ),
      if (offers.isNotEmpty) OfferBanner(offer: offers.first, onTap: () => widget.goTab(2)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, ${firstName(Api.me?['name'])} 👋'),
        actions: [
          const NotificationBell(),
          RefreshButton(onPressed: reload),
        ],
      ),
      body: AsyncStateView(
        loading: loading,
        error: error,
        data: data,
        onRetry: reload,
        builder: (context, d) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: Gaps.page, children: content(d)),
        ),
      ),
    );
  }
}

/// Carte membre (dégradé de marque si l'abonnement est actif, neutre sinon). Texte blanc ≥ 5:1.
class MemberCard extends StatelessWidget {
  final Json me;
  final SubscriptionStatus status;

  const MemberCard({super.key, required this.me, required this.status});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final plan = me['plan_id'] == null ? '—' : Refs.name('plans', me['plan_id']);
    final number = '${me['id']}'.padLeft(4, '0');
    final header = me['role'] == 'coach' ? 'IRONFIT · CARTE MEMBRE · COACH' : 'IRONFIT · CARTE MEMBRE';
    return Semantics(
      container: true,
      label: 'Carte membre IronFit. ${me['name']}, numéro $number, abonnement $plan. ${status.label}.',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: status.active ? AppColors.brandGradient : AppColors.inactiveGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: Colors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.fitness_center, color: Colors.white),
                    Gaps.w8,
                    Flexible(
                      child: Text(header, style: t.labelMedium?.copyWith(color: Colors.white, letterSpacing: 1.2)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('${me['name']}', style: t.headlineSmall?.copyWith(color: Colors.white)),
                Text('N° $number · $plan'),
                Gaps.h12,
                DecoratedBox(
                  decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    child: Text(status.label, style: t.labelMedium?.copyWith(color: Colors.white)),
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

/// Bandeau de l'offre du moment.
class OfferBanner extends StatelessWidget {
  final Json offer;
  final VoidCallback onTap;
  const OfferBanner({super.key, required this.offer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: Gaps.md),
      child: Material(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(Gaps.radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: Gaps.card,
            child: Row(
              children: [
                Icon(Icons.local_offer, size: 32, color: cs.onPrimaryContainer),
                Gaps.w12,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${offer['title']} · -${offer['discount'] ?? 0}%',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onPrimaryContainer),
                      ),
                      Text('${offer['descr'] ?? ''}', style: TextStyle(color: cs.onPrimaryContainer)),
                    ],
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
