import '../widgets/member_design.dart';
import '../core/theme/brand.dart';
import 'planning_screen.dart';
import '../widgets/member_fitness_hero.dart';
import 'membership_screen.dart';
import 'stripe_payments_screen.dart';
import 'gym_location_screen.dart';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../services/catalog_service.dart';
import '../services/user_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/form_dialog.dart';
import 'coaches_screen.dart';
import 'notifications_screen.dart';
import 'program_screens.dart';

// Écrans de l'espace membre : utilisés par les athlètes et par les coachs dans « Mon entraînement ».

// =============== ACCUEIL MEMBRE ===============
class MemberHome extends StatefulWidget {
  final void Function(int) goTab;
  const MemberHome({super.key, required this.goTab});
  @override
  State<MemberHome> createState() => _MemberHomeState();
}

class _MemberHomeState extends State<MemberHome> {
  bool loading = true;
  String? error;
  List<Json> classes = [],
      ann = [],
      promos = [],
      reqs = [],
      measures = [],
      programs = [],
      workouts = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  final Map<String, String> _failures = {};
  bool _refreshing = false;
  Future<void> load() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await Api.refreshMe();
      final me = Api.myId!;
      Future<List<Json>> fetch(
        String label,
        String path,
        List<Json> previous,
      ) async {
        try {
          final result = await Api.list(path);
          _failures.remove(label);
          return result;
        } catch (_) {
          _failures[label] = 'Impossible de charger $label.';
          return previous;
        }
      }

      final data = await Future.wait([
        fetch('les cours', 'classes', classes),
        fetch('les annonces', 'announcements', ann),
        fetch('les offres', 'promos', promos),
        fetch('les demandes', 'requests', reqs),
        fetch('les mesures', 'measures?member_id=$me', measures),
        fetch('les programmes', 'programs?scope=personal', programs),
        fetch('les entraînements', 'workouts?limit=50', workouts),
      ]);
      if (!mounted) return;
      classes = data[0];
      ann = data[1];
      promos = data[2];
      reqs = data[3];
      measures = data[4];
      programs = data[5];
      workouts = data[6];
      error = null;
    } catch (_) {
      error =
          'Connexion indisponible. Vos informations peuvent ne pas être à jour.';
    } finally {
      if (mounted)
        setState(() {
          loading = false;
          _refreshing = false;
        });
    }
  }

  Future<void> cancelRequest(int id) async {
    if (await attempt(context, () => UserService.cancelRequest(id))) load();
  }

  Widget memberCard() {
    final me = Api.user!, end = me.subEnd;
    final active = me.hasActiveSubscription;
    final left = end == null
        ? 0
        : DateTime.parse(end).difference(DateTime.now()).inDays + 1;
    final status = end == null
        ? 'Aucun abonnement'
        : (active
              ? 'Actif · $left jour${left > 1 ? "s" : ""} restant${left > 1 ? "s" : ""}'
              : 'Expiré le $end');
    if (!Api.isCoach && !Api.isAdmin) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const IconBadge(Icons.credit_card_rounded),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      me.planName ?? 'Carte membre',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'N° ${'${me.id}'.padLeft(4, '0')} · ${me.name}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    StatusPill(
                      status,
                      color: active
                          ? AppColors.success
                          : Theme.of(context).colorScheme.error,
                      icon: active
                          ? Icons.verified_rounded
                          : Icons.error_outline,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.credit_card_rounded,
                color: AppColors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                me.isCoach ? 'CARTE MEMBRE · COACH' : 'CARTE MEMBRE',
                style: const TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1.6,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            me.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'N° ${'${me.id}'.padLeft(4, '0')} · ${me.planId == null ? 'Sans formule' : (me.planName ?? 'Abonnement')}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          StatusPill(
            status,
            color: active ? AppColors.amber : const Color(0xFFFF8A80),
            icon: active ? Icons.verified_rounded : Icons.error_outline,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Api.user!;
    final active = me.hasActiveSubscription;
    final pending = reqs.where((r) => r['status'] == 'pending').toList();
    final dow = DateTime.now().weekday - 1;
    final mine =
        classes
            .where(
              (c) =>
                  isTrue(c['mine']) &&
                  (!isMemberDesign ||
                      DateTime.tryParse(
                            '${c['session_date']}T${c['time']}',
                          )?.isBefore(DateTime.now()) !=
                          true),
            )
            .toList()
          ..sort((a, b) {
            final ka = (((a['day'] as int) - dow) + 7) % 7,
                kb = (((b['day'] as int) - dow) + 7) % 7;
            return ka != kb
                ? ka.compareTo(kb)
                : '${a['time']}'.compareTo('${b['time']}');
          });
    final ago7 = DateTime.now().subtract(const Duration(days: 7));
    final week = workouts
        .where(
          (w) => (DateTime.tryParse('${w['done_on']}') ?? DateTime(2000))
              .isAfter(ago7),
        )
        .length;
    final sorted = [...measures]
      ..sort((a, b) => '${b['measured_on']}'.compareTo('${a['measured_on']}'));
    final weight = sorted.where((m) => m['weight'] != null).isEmpty
        ? '—'
        : '${sorted.firstWhere((m) => m['weight'] != null)['weight']} kg';
    final today = todayIso();
    final offers = promos
        .where(
          (p) => p['until'] == null || '${p['until']}'.compareTo(today) >= 0,
        )
        .toList();
    final activePrograms = programs.where((p) => isTrue(p['active'])).toList();
    final cs = Theme.of(context).colorScheme;
    final membershipCards = <Widget>[
      memberCard(),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          icon: const Icon(Icons.card_membership_outlined),
          label: const Text('Gérer mon abonnement'),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MembershipPage()),
            );
            if (mounted) load();
          },
        ),
      ),
    ];
    final courseCards = <Widget>[
      SectionHeader(
        'Mes prochains cours',
        action: TextButton(
          onPressed: () => widget.goTab(1),
          child: const Text('Planning'),
        ),
      ),
      if (mine.isEmpty && !_failures.containsKey('les cours'))
        Card(
          child: Empty(
            Icons.event_rounded,
            'Aucun cours réservé.',
            cta: 'Voir le planning',
            onTap: () => widget.goTab(1),
          ),
        )
      else
        for (final c in mine.take(3))
          if (isMemberDesign)
            MemberSessionCard(
              session: c,
              action: TextButton.icon(
                onPressed: () => widget.goTab(1),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Voir le planning'),
              ),
            )
          else
            Card(
              child: ListTile(
                leading: const IconBadge(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                ),
                title: Text('${c['title']}'),
                subtitle: Text(
                  '${c['session_date'] ?? dayLabel(c['day'] as int)} · ${c['time']} · ${c['coach_name'] ?? '—'}',
                ),
              ),
            ),
    ];
    final programCards = <Widget>[
      SectionHeader(
        'Mes programmes',
        action: TextButton(
          onPressed: () => widget.goTab(3),
          child: const Text('Tout voir'),
        ),
      ),
      if (activePrograms.isEmpty && !_failures.containsKey('les programmes'))
        isMemberDesign
            ? MemberEmptyCard(
                message: 'Aucun programme actif.',
                action: 'Créer ou trouver un coach',
                onTap: () => widget.goTab(3),
              )
            : Card(
                child: Empty(
                  Icons.list_alt_rounded,
                  'Aucun programme actif.',
                  cta: 'Créer ou trouver un coach',
                  onTap: () => widget.goTab(3),
                ),
              )
      else
        for (final p in activePrograms.take(3))
          Card(
            child: ListTile(
              leading: IconBadge(
                p['coach_id'] == null
                    ? Icons.person_rounded
                    : Icons.sports_rounded,
              ),
              title: Text('${p['title']}'),
              subtitle: Text(
                '${p['coach_id'] == null ? 'Personnel' : 'Par ${p['coach_name']}'} · ${p['sessions']} séance(s)${p['last_done'] == null ? '' : ' · dernière ${p['last_done']}'}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProgramDetailPage(p['id'] as int),
                  ),
                );
                load();
              },
            ),
          ),
    ];
    final activityCards = <Widget>[
      LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: constraints.maxWidth < (isMemberDesign ? 340 : 420)
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3,
              child: kpiCard(
                context,
                Icons.local_fire_department_rounded,
                'Séances (7 j)',
                _failures.containsKey('les entraînements') ? '—' : '$week',
                color: AppColors.ember,
              ),
            ),
            SizedBox(
              width: constraints.maxWidth < (isMemberDesign ? 340 : 420)
                  ? (constraints.maxWidth - 8) / 2
                  : (constraints.maxWidth - 16) / 3,
              child: kpiCard(
                context,
                Icons.event_available_rounded,
                'Réservations',
                _failures.containsKey('les cours') ? '—' : '${mine.length}',
              ),
            ),
            SizedBox(
              width: constraints.maxWidth < (isMemberDesign ? 340 : 420)
                  ? (constraints.maxWidth - 8) / 2
                  : (constraints.maxWidth - 16) / 3,
              child: kpiCard(
                context,
                Icons.monitor_weight_rounded,
                'Poids',
                weight,
                color: AppColors.info,
              ),
            ),
          ],
        ),
      ),
    ];
    return Scaffold(
      appBar: AppBar(
        title: isMemberDesign
            ? const BrandLogo(size: 58, transparent: true)
            : Text('Bonjour, ${me.firstName} 👋'),
        actions: [
          if (isMemberDesign)
            IconButton(
              tooltip: 'Mon profil',
              onPressed: () => widget.goTab(4),
              icon: CircleAvatar(
                radius: 17,
                child: Text(me.firstName.isEmpty ? 'I' : me.firstName[0]),
              ),
            ),
          NotificationBell(page: () => const NotificationsPage()),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AsyncBody(
        loading: loading,
        error: null,
        onRetry: load,
        builder: () => RefreshIndicator(
          onRefresh: load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (_refreshing) const LinearProgressIndicator(),
              if (error != null || _failures.isNotEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          error ??
                              'Certaines informations ne sont pas disponibles.',
                        ),
                        for (final message in _failures.values) Text(message),
                        TextButton(
                          onPressed: _refreshing ? null : load,
                          child: const Text('Réessayer'),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!isMemberDesign) ...membershipCards,
              MemberFitnessHero(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isMemberDesign
                          ? 'Bonjour, ${me.firstName} 👋'
                          : 'VOTRE PROCHAIN OBJECTIF',
                      style: TextStyle(
                        color: AppColors.amber,
                        letterSpacing: 1.2,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      activePrograms.isNotEmpty
                          ? '${activePrograms.first['title']}'
                          : isMemberDesign
                          ? 'Prêt à atteindre vos objectifs ?'
                          : 'Votre prochaine séance commence ici',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Retrouvez votre programme ou réservez un cours à la salle.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(
                        activePrograms.isNotEmpty
                            ? 'Ouvrir mon programme'
                            : 'Voir les cours',
                      ),
                      onPressed: () async {
                        if (activePrograms.isEmpty) {
                          widget.goTab(1);
                          return;
                        }
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProgramDetailPage(
                              activePrograms.first['id'] as int,
                            ),
                          ),
                        );
                        if (mounted) load();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (isMemberDesign) ...membershipCards,
              if (pending.isNotEmpty)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  child: ListTile(
                    leading: const IconBadge(
                      Icons.hourglass_top_rounded,
                      color: AppColors.info,
                    ),
                    title: Text(
                      'Demande en attente : ${pending.first['plan_name']}',
                    ),
                    subtitle: const Text(
                      'Réglez à l\'accueil : l\'abonnement sera activé par l\'administrateur.',
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          cancelRequest(pending.first['id'] as int),
                      child: const Text('Annuler'),
                    ),
                  ),
                )
              else if (!active)
                Card(
                  margin: const EdgeInsets.only(top: 12),
                  color: cs.primaryContainer,
                  child: ListTile(
                    leading: const IconBadge(Icons.card_membership_rounded),
                    title: Text(
                      me.subEnd == null
                          ? 'Pas encore d\'abonnement'
                          : 'Votre abonnement a expiré',
                      style: TextStyle(color: cs.onPrimaryContainer),
                    ),
                    subtitle: Text(
                      'Choisissez une formule pour réserver vos cours.',
                      style: TextStyle(color: cs.onPrimaryContainer),
                    ),
                    trailing: FilledButton(
                      onPressed: () => widget.goTab(2),
                      child: const Text('Choisir'),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              if (isMemberDesign) ...[
                ...courseCards,
                ...programCards,
                const SectionHeader('Votre activité'),
                ...activityCards,
              ] else ...[
                ...activityCards,
                ...programCards,
                ...courseCards,
              ],
              if (ann.isNotEmpty) const SectionHeader('Annonces'),
              for (final a in ann.take(2))
                Card(
                  child: ListTile(
                    leading: const IconBadge(Icons.campaign_rounded),
                    title: Text('${a['title']}'),
                    subtitle: Text('${a['body'] ?? ''}'),
                  ),
                ),
              if (offers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => widget.goTab(2),
                    child: Ink(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: AppColors.amberGradient,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_rounded,
                            size: 32,
                            color: AppColors.ink,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${offers.first['title']} · -${offers.first['discount'] ?? 0}%',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${offers.first['descr'] ?? ''}',
                                  style: const TextStyle(color: AppColors.ink),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.ink,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const IconBadge(Icons.location_on_outlined),
                  title: const Text('Notre salle'),
                  subtitle: const Text('Adresse, carte et itinéraire'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GymLocationPage()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============== EXPLORER : tarifs, coachs, offres, boutique, annonces ===============
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  bool loading = true;
  List<Json> plans = [], promos = [], products = [], ann = [], reqs = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await Future.wait([
      CrudService.safeList('plans'),
      CrudService.safeList('promos'),
      CrudService.safeList('products'),
      CrudService.safeList('announcements'),
      CrudService.safeList('requests'),
    ]);
    plans = r[0];
    promos = r[1];
    products = r[2];
    ann = r[3];
    reqs = r[4];
    if (mounted) setState(() => loading = false);
  }

  Future<void> choose(Json p) async {
    final online = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choisir le règlement'),
        content: const Text(
          'Paiement sécurisé par carte en mode test, ou règlement à l’accueil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('À l’accueil'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Carte · Stripe test'),
          ),
        ],
      ),
    );
    if (!mounted || online == null) return;
    if (online) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StripePaymentsPage(plan: p)),
      );
      if (mounted) load();
      return;
    }
    if (!await confirm(
      context,
      'Demander « ${p['name']} » ?',
      body:
          '${money(p['price'], currency: '${p['currency'] ?? 'EUR'}')} · ${p['duration'] ?? ''}\nL\'abonnement sera activé par l\'administrateur après paiement à l\'accueil.',
      ok: 'Envoyer la demande',
    ))
      return;
    if (mounted &&
        await attempt(
          context,
          () => UserService.requestPlan(p['id'] as int),
          success: 'Demande envoyée ✓',
        ))
      load();
  }

  Widget plansTab() {
    if (plans.isEmpty)
      return const Empty(
        Icons.credit_card_off_rounded,
        'Aucun tarif disponible pour le moment',
      );
    final pending = reqs.where((r) => r['status'] == 'pending').toList();
    final tt = Theme.of(context).textTheme;
    final accent = Theme.of(context).brightness == Brightness.dark
        ? AppColors.amber
        : AppColors.amberText;
    return GridView.extent(
      padding: const EdgeInsets.all(16),
      maxCrossAxisExtent: 420,
      mainAxisExtent: 230,
      crossAxisSpacing: 8,
      children: [
        for (final p in plans)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${p['name']}', style: tt.titleLarge),
                      ),
                      if (Api.user!.planId == p['id'])
                        const StatusPill(
                          'Mon offre',
                          color: AppColors.success,
                          icon: Icons.check_rounded,
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    money(p['price'], currency: '${p['currency'] ?? 'EUR'}'),
                    style: tt.headlineMedium?.copyWith(color: accent),
                  ),
                  Text('${p['duration'] ?? ''}', style: tt.bodyMedium),
                  if ((p['descr'] ?? '') != '')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${p['descr']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: pending.isNotEmpty ? null : () => choose(p),
                      child: Text(
                        pending.any((r) => r['plan_id'] == p['id'])
                            ? 'Demande envoyée'
                            : (Api.user!.planId == p['id']
                                  ? 'Renouveler'
                                  : 'Choisir'),
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

  Widget promosTab() {
    if (promos.isEmpty)
      return const Empty(
        Icons.local_offer_outlined,
        'Aucune offre en ce moment',
      );
    final today = todayIso();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final p in promos)
          Builder(
            builder: (_) {
              final expired =
                  p['until'] != null && '${p['until']}'.compareTo(today) < 0;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundColor: expired
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : AppColors.amber,
                    foregroundColor: AppColors.ink,
                    child: Text(
                      '-${p['discount'] ?? 0}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  title: Text('${p['title']}'),
                  subtitle: Text(
                    '${p['descr'] ?? ''}\n${expired ? "Expirée" : "Valable jusqu'au ${p['until'] ?? '—'}"}',
                  ),
                  isThreeLine: true,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget shopTab() {
    if (products.isEmpty)
      return const Empty(Icons.storefront_rounded, 'La boutique est vide');
    final accent = Theme.of(context).brightness == Brightness.dark
        ? AppColors.amber
        : AppColors.amberText;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'Achat directement à l\'accueil de la salle.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: GridView.extent(
            padding: const EdgeInsets.all(16),
            maxCrossAxisExtent: 220,
            childAspectRatio: 1.0,
            mainAxisSpacing: 6,
            crossAxisSpacing: 8,
            children: [
              for (final p in products)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const IconBadge(Icons.shopping_bag_rounded),
                        Text(
                          '${p['name']}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          money(p['price'], currency: 'TND'),
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        num2(p['stock']) <= 0
                            ? const StatusPill(
                                'Rupture',
                                color: AppColors.danger,
                              )
                            : (num2(p['stock']) <= 5
                                  ? const StatusPill(
                                      'Stock limité',
                                      color: AppColors.warning,
                                    )
                                  : const StatusPill(
                                      'Disponible',
                                      color: AppColors.success,
                                    )),
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

  Widget annTab() => ann.isEmpty
      ? const Empty(Icons.campaign_outlined, 'Aucune annonce')
      : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final a in ann)
              Card(
                child: ListTile(
                  leading: const IconBadge(Icons.campaign_rounded),
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
          flexibleSpace: isMemberDesign
              ? Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 70),
                    child: MemberIllustration(size: 54),
                  ),
                )
              : null,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Tarifs'),
              Tab(text: 'Coachs'),
              Tab(text: 'Offres'),
              Tab(text: 'Boutique'),
              Tab(text: 'Annonces'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Actualiser',
              onPressed: load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  plansTab(),
                  const CoachesTab(),
                  promosTab(),
                  shopTab(),
                  annTab(),
                ],
              ),
      ),
    );
  }
}

// =============== MON ESPACE ===============
class MySpacePage extends StatelessWidget {
  const MySpacePage({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, String s, Widget page, {Color? color}) =>
        Card(
          child: ListTile(
            leading: IconBadge(i, color: color),
            title: Text(t),
            subtitle: Text(s),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => page),
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Mon espace')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (!Api.isCoach && !Api.isAdmin) ...[
            MemberFitnessHero(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Chaque séance compte.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Vos programmes, vos efforts, votre progression.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          const SectionHeader('Entraînement'),
          item(
            Icons.list_alt_rounded,
            'Mes programmes',
            'Programmes personnels et programmes de mon coach',
            const ProgramsPage(),
          ),
          item(
            Icons.local_fire_department_rounded,
            'Mes séances',
            'Historique d\'entraînement et commentaires du coach',
            const WorkoutHistoryPage(),
            color: AppColors.ember,
          ),
          item(
            Icons.show_chart_rounded,
            'Ma progression',
            'Poids, masse grasse, historique',
            ProgressPage(memberId: Api.myId!, title: 'Ma progression'),
            color: AppColors.info,
          ),
          if (isMemberDesign)
            item(
              Icons.event_available_rounded,
              'Mes réservations',
              'Cours à venir et vérification de présence',
              const PlanningPage(reservationsOnly: true),
            ),
          const SectionHeader('Suivi'),
          item(
            Icons.sports_rounded,
            'Mes coachs',
            'Suivi en cours et demandes',
            const MyCoachesPage(),
          ),
          item(
            Icons.how_to_reg_rounded,
            'Mes présences',
            'Mes venues aux cours collectifs',
            const AttendancePage(),
            color: AppColors.success,
          ),
          item(
            Icons.card_membership_outlined,
            'Mon abonnement',
            'Formule, renouvellement, paiements et factures',
            const MembershipPage(),
          ),
        ],
      ),
    );
  }
}

/// Courbe de poids et historique des mesures d'un membre (le sien, ou celui d'un client pour son coach).
class ProgressView extends StatefulWidget {
  final int memberId;
  const ProgressView({super.key, required this.memberId});
  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> {
  List<Json> ms = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final l = await UserService.measures(widget.memberId);
      l.sort((a, b) => '${a['measured_on']}'.compareTo('${b['measured_on']}'));
      ms = l;
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> add() async {
    final r = await formDialog(context, 'Nouvelle mesure', const [
      DField('measured_on', 'Date', type: DType.date, required: true),
      DField('weight', 'Poids (kg)', type: DType.decimal, min: 20, max: 400),
      DField('body_fat', 'Masse grasse (%)', type: DType.decimal, max: 100),
      DField('note', 'Note'),
    ], submit: (v) => UserService.addMeasure(widget.memberId, v));
    if (r != null) load();
  }

  @override
  Widget build(BuildContext context) {
    final w = [
      for (final m in ms)
        if (m['weight'] != null) num2(m['weight']),
    ];
    final cs = Theme.of(context).colorScheme;
    final delta = w.length >= 2 ? w.last - w.first : 0.0;
    final fat = ms.where((m) => m['body_fat'] != null).toList();
    return AsyncBody(
      loading: loading,
      error: error,
      onRetry: load,
      builder: () => RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: add,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Ajouter une mesure'),
              ),
            ),
            if (ms.isEmpty)
              const Empty(
                Icons.show_chart_rounded,
                'Aucune mesure pour le moment.',
              )
            else ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: kpiCard(
                      context,
                      Icons.monitor_weight_rounded,
                      'Poids actuel',
                      w.isEmpty ? '—' : '${w.last} kg',
                    ),
                  ),
                  Expanded(
                    child: kpiCard(
                      context,
                      delta <= 0
                          ? Icons.trending_down_rounded
                          : Icons.trending_up_rounded,
                      'Évolution',
                      '${delta > 0 ? "+" : ""}${delta.toStringAsFixed(1)} kg',
                      color: delta <= 0 ? AppColors.success : AppColors.ember,
                    ),
                  ),
                  Expanded(
                    child: kpiCard(
                      context,
                      Icons.percent_rounded,
                      'Masse grasse',
                      fat.isEmpty ? '—' : '${fat.last['body_fat']} %',
                      color: AppColors.info,
                    ),
                  ),
                ],
              ),
              if (w.length >= 2)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      height: 190,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: LinePainter(w, cs.primary, cs.onSurface),
                      ),
                    ),
                  ),
                ),
              const SectionHeader('Historique'),
              for (final m in ms.reversed)
                Card(
                  child: ListTile(
                    leading: const IconBadge(Icons.monitor_weight_outlined),
                    title: Text(
                      '${m['weight'] ?? '—'} kg · ${m['body_fat'] ?? '—'} % MG',
                    ),
                    subtitle: Text(
                      '${m['measured_on'] ?? '—'} · ${m['note'] ?? ''}',
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProgressPage extends StatelessWidget {
  final int memberId;
  final String title;
  const ProgressPage({super.key, required this.memberId, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ProgressView(memberId: memberId),
  );
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Json> list = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final l = await UserService.checkins(Api.myId!);
      l.sort((a, b) => '${b['checkin_on']}'.compareTo('${a['checkin_on']}'));
      list = l;
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final month = todayIso().substring(0, 7);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes présences')),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => list.isEmpty
            ? const Empty(
                Icons.how_to_reg_rounded,
                'Aucune présence enregistrée.\nVos venues sont pointées par le coach pendant les cours.',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: kpiCard(
                          context,
                          Icons.calendar_month_rounded,
                          'Ce mois',
                          '${list.where((c) => '${c['checkin_on']}'.startsWith(month)).length}',
                        ),
                      ),
                      Expanded(
                        child: kpiCard(
                          context,
                          Icons.emoji_events_rounded,
                          'Total',
                          '${list.length}',
                          color: AppColors.ember,
                        ),
                      ),
                      Expanded(
                        child: kpiCard(
                          context,
                          Icons.history_rounded,
                          'Dernière venue',
                          '${list.first['checkin_on'] ?? '—'}'.replaceFirst(
                            RegExp(r'^\d{4}-'),
                            '',
                          ),
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                  const SectionHeader('Historique'),
                  for (final c in list)
                    Card(
                      child: ListTile(
                        leading: const IconBadge(
                          Icons.check_circle_rounded,
                          color: AppColors.success,
                        ),
                        title: Text('${c['note'] ?? 'Entraînement'}'),
                        subtitle: Text('${c['checkin_on'] ?? '—'}'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
