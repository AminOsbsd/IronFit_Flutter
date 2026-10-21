import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../services/coach_service.dart';
import '../services/notification_service.dart';
import '../services/planning_service.dart';
import '../widgets/common_widgets.dart';
import 'member_screens.dart';
import 'notifications_screen.dart';
import 'planning_screen.dart';
import 'program_screens.dart';

// Espace coach : tableau de bord, clients, suivi d'un client.
// Le serveur limite toutes ces données aux clients dont la relation de coaching est active.

// =============== ACCUEIL COACH ===============
class CoachHome extends StatefulWidget {
  const CoachHome({super.key});
  @override
  State<CoachHome> createState() => _CoachHomeState();
}

class _CoachHomeState extends State<CoachHome> {
  bool loading = true;
  String? error;
  Map<String, dynamic> st = {};
  List<Map<String, dynamic>> pending = [], today = [];

  List<Map<String, dynamic>> L(String k) => ((st[k] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      await Api.refreshMe();
      st = await CoachService.stats();
      pending = (await CoachService.clients()).where((l) => l['status'] == 'pending').toList();
      final dow = DateTime.now().weekday - 1;
      today = (await PlanningService.classes()).where((c) => c['day'] == dow && c['coach_id'] == Api.myId).toList();
      NotificationService.refreshUnread();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> answer(Map<String, dynamic> l, bool accept) async {
    if (await attempt(context, () => CoachService.answer(l['id'] as int, accept: accept), success: accept ? '${l['client_name']} fait partie de vos clients ✓' : null)) load();
  }

  @override
  Widget build(BuildContext context) {
    final me = Api.user!;
    final expiring = L('expiring'), maint = L('maintenance'), fill = L('fill');
    return Scaffold(
      appBar: AppBar(
        title: Text('Coach ${me.firstName}'),
        actions: [NotificationBell(page: () => const NotificationsPage()), IconButton(tooltip: 'Actualiser', onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            HeroCard(
              child: Row(children: [
                InitialAvatar(me.name, radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('ESPACE COACH', style: TextStyle(color: Colors.white70, letterSpacing: 1.6, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text(me.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    Text(me.specialty ?? 'Coach IronFit', style: const TextStyle(color: AppColors.amber, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (pending.isNotEmpty) StatusPill('${pending.length} demande${pending.length > 1 ? 's' : ''}', color: AppColors.amber, icon: Icons.person_add_alt_1_rounded),
              ]),
            ),
            const SizedBox(height: 12),
            kpiGrid([
                kpiCard(context, Icons.groups, 'Clients suivis', '${st['clients'] ?? 0}'),
                kpiCard(context, Icons.list_alt, 'Programmes actifs', '${st['programs'] ?? 0}'),
                kpiCard(context, Icons.local_fire_department, 'Séances clients (7 j)', '${st['workouts_7d'] ?? 0}', color: AppColors.success),
                kpiCard(context, Icons.rate_review, 'Séances à commenter', '${st['to_review'] ?? 0}', color: AppColors.ember),
              ]),
            if (pending.isNotEmpty) ...[
              sectionTitle(context, 'Demandes de suivi'),
              for (final l in pending)
                Card(
                  child: ListTile(
                    leading: const IconBadge(Icons.person_add_alt_1_rounded, color: AppColors.info),
                    title: Text('${l['client_name']}'),
                    subtitle: Text('@${l['client_login']} · demandé le ${dateOnly(l['created'])}'),
                    trailing: Wrap(spacing: 4, children: [
                      TextButton(onPressed: () => answer(l, false), child: const Text('Refuser')),
                      FilledButton(onPressed: () => answer(l, true), child: const Text('Accepter')),
                    ]),
                  ),
                ),
            ],
            sectionTitle(context, 'Mes cours aujourd\'hui'),
            if (today.isEmpty) const Card(child: Empty(Icons.event_busy, 'Aucun cours à animer aujourd\'hui')),
            for (final c in today)
              Card(
                child: ListTile(
                  leading: const IconBadge(Icons.schedule_rounded),
                  title: Text('${c['time']} · ${c['title']}'),
                  subtitle: Text('${c['taken']}/${c['spots']} inscrits'),
                  trailing: OutlinedButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantsPage(c))); load(); }, child: const Text('Pointer')),
                ),
              ),
            if (expiring.isNotEmpty) ...[
              sectionTitle(context, 'Abonnements de mes clients qui expirent'),
              for (final a in expiring) Card(child: ListTile(leading: const IconBadge(Icons.timer_outlined, color: AppColors.warning), title: Text('${a['name']}'), subtitle: Text('Expire le ${a['sub_end']}'))),
            ],
            if (maint.isNotEmpty) ...[
              sectionTitle(context, 'Matériel à vérifier'),
              Card(child: ListTile(leading: const IconBadge(Icons.build_rounded, color: AppColors.warning), title: Text(maint.map((e) => e['name']).join(', ')))),
            ],
            if (fill.isNotEmpty) ...[
              sectionTitle(context, 'Remplissage de mes cours'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    for (final c in fill)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          SizedBox(width: 130, child: Text('${c['title']} · ${dayShort[((c['day'] ?? 0) as int) % 7]}', overflow: TextOverflow.ellipsis)),
                          Expanded(child: LinearProgressIndicator(value: num2(c['spots']) == 0 ? 0 : (num2(c['taken']) / num2(c['spots'])).clamp(0.0, 1.0).toDouble(), minHeight: 8, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 8),
                          Text('${c['taken']}/${c['spots']}'),
                        ]),
                      ),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// =============== MES CLIENTS ===============
class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  List<Map<String, dynamic>> links = [];
  bool loading = true;
  String? error;
  String q = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      links = await CoachService.clients();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> answer(Map<String, dynamic> l, bool accept) async {
    if (await attempt(context, () => CoachService.answer(l['id'] as int, accept: accept))) load();
  }

  @override
  Widget build(BuildContext context) {
    final pending = links.where((l) => l['status'] == 'pending').toList();
    final active = links.where((l) => l['status'] == 'active' && '${l['client_name']}'.toLowerCase().contains(q.toLowerCase())).toList();
    final today = todayIso();
    return Scaffold(
      appBar: AppBar(title: const Text('Mes clients'), actions: [IconButton(tooltip: 'Actualiser', onPressed: load, icon: const Icon(Icons.refresh))]),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.all(12), physics: const AlwaysScrollableScrollPhysics(), children: [
            if (pending.isNotEmpty) ...[
              sectionTitle(context, 'Demandes en attente (${pending.length})'),
              for (final l in pending)
                Card(
                  child: ListTile(
                    leading: const IconBadge(Icons.person_add_alt_1_rounded, color: AppColors.info),
                    title: Text('${l['client_name']}'),
                    subtitle: Text('@${l['client_login']}'),
                    trailing: Wrap(spacing: 4, children: [
                      IconButton(tooltip: 'Refuser', onPressed: () => answer(l, false), icon: const Icon(Icons.close)),
                      IconButton.filled(tooltip: 'Accepter', onPressed: () => answer(l, true), icon: const Icon(Icons.check)),
                    ]),
                  ),
                ),
            ],
            sectionTitle(context, 'Clients suivis'),
            TextField(decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Rechercher un client…', border: OutlineInputBorder(), isDense: true), onChanged: (s) => setState(() => q = s)),
            const SizedBox(height: 8),
            if (active.isEmpty) Card(child: Empty(Icons.groups, q.isEmpty ? 'Aucun client pour le moment.\nLes membres peuvent vous choisir depuis Explorer → Coachs, ou l\'administration peut vous en attribuer.' : 'Aucun résultat')),
            for (final l in active)
              Card(
                child: ListTile(
                  leading: InitialAvatar('${l['client_name']}'),
                  title: Text('${l['client_name']}'),
                  subtitle: Text([
                    l['client_sub_end'] == null ? 'Sans abonnement' : ('${l['client_sub_end']}'.compareTo(today) < 0 ? 'Abonnement expiré' : 'Abonné jusqu\'au ${l['client_sub_end']}'),
                    'Dernière séance : ${l['last_workout'] ?? '—'}',
                  ].join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailPage(l)));
                    load();
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

// =============== SUIVI D'UN CLIENT ===============
class ClientDetailPage extends StatelessWidget {
  final Map<String, dynamic> link;
  const ClientDetailPage(this.link, {super.key});

  int get clientId => link['client_id'] as int;

  Future<void> end(BuildContext context) async {
    if (!await confirm(context, 'Arrêter le suivi de ${link['client_name']} ?', body: 'Vous n\'aurez plus accès à ses données ni aux programmes que vous lui avez écrits.', ok: 'Arrêter')) return;
    if (context.mounted && await attempt(context, () => CoachService.endLink(link['id'] as int)) && context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text('${link['client_name']}'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (_) => end(context),
                itemBuilder: (_) => const [PopupMenuItem(value: 'end', child: Text('Arrêter le suivi'))],
              ),
            ],
            bottom: const TabBar(tabs: [Tab(text: 'Programmes'), Tab(text: 'Séances'), Tab(text: 'Progression')]),
          ),
          body: Column(children: [
            if (link['client_phone'] != null)
              ListTile(dense: true, leading: const Icon(Icons.phone_rounded), title: Text('${link['client_phone']}')),
            Expanded(
              child: TabBarView(children: [
                ProgramList(scope: 'coaching', clientId: clientId, emptyText: 'Aucun programme pour ce client.\nCréez-en un pour commencer le suivi.'),
                WorkoutList(userId: clientId),
                ProgressView(memberId: clientId),
              ]),
            ),
          ]),
        ),
      );
}
