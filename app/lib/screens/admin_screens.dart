import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../services/admin_service.dart';
import '../services/notification_service.dart';
import '../services/planning_service.dart';
import '../widgets/common_widgets.dart';
import '../models/module.dart';
import 'notifications_screen.dart';
import 'planning_screen.dart';

// =============== TABLEAU DE BORD ADMIN ===============
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  bool loading = true;
  String? error;
  Map<String, dynamic> st = {};
  List<Map<String, dynamic>> today = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  List<Map<String, dynamic>> L(String k) => ((st[k] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> load() async {
    try {
      await Api.refreshMe();
      st = await AdminService.stats();
      await Refs.load();
      final dow = DateTime.now().weekday - 1;
      today = (await PlanningService.classes()).where((c) => c['day'] == dow).toList();
      NotificationService.refreshUnread();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> renew(Map<String, dynamic> a) async {
    final plans = Refs.data['plans'] ?? <Map<String, dynamic>>[];
    if (plans.isEmpty) {
      snack(context, 'Aucun tarif défini');
      return;
    }
    Object? plan = plans.any((p) => p['id'] == a['plan_id']) ? a['plan_id'] : plans.first['id'];
    String method = payMethods.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text('Renouveler ${a['name']}'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButton<Object?>(
              value: plan, isExpanded: true,
              items: [for (final p in plans) DropdownMenuItem<Object?>(value: p['id'], child: Text('${p['name']} — ${money(p['price'])}'))],
              onChanged: (x) => set(() => plan = x),
            ),
            DropdownButton<String>(value: method, isExpanded: true, items: [for (final e in payMethods) DropdownMenuItem(value: e, child: Text(e))], onChanged: (x) => set(() => method = x!)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Renouveler')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (await attempt(context, () => AdminService.renew(a['id'] as int, planId: plan, method: method), success: 'Abonnement renouvelé, paiement enregistré ✓')) load();
  }

  Widget alert(IconData i, String text, Color c, {VoidCallback? onTap}) => Card(
        child: ListTile(leading: IconBadge(i, color: c), title: Text(text), trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded), onTap: onTap),
      );

  Future<void> open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    load();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = Api.user!;
    final expiring = L('expiring'), lapsed = L('lapsed'), low = L('low_stock'), maint = L('maintenance'), rev = L('revenue'), fill = L('fill');
    final pending = (st['pending'] ?? 0) as int, pendingCoach = (st['pending_coachings'] ?? 0) as int;
    final month = todayIso().substring(0, 7);
    final monthRev = rev.where((r) => r['m'] == month).fold<double>(0, (s, r) => s + num2(r['total']));
    final alerts = <Widget>[
      if (pending > 0) alert(Icons.assignment_ind, '$pending demande${pending > 1 ? "s" : ""} d\'abonnement à valider', cs.primary, onTap: () => open(const RequestsPage())),
      if (pendingCoach > 0) alert(Icons.sports, '$pendingCoach demande${pendingCoach > 1 ? "s" : ""} de coaching en attente de réponse du coach', AppColors.info, onTap: () => open(const CoachingAdminPage())),
      if (expiring.isNotEmpty) alert(Icons.timer, '${expiring.length} abonnement${expiring.length > 1 ? "s" : ""} expire${expiring.length > 1 ? "nt" : ""} cette semaine', AppColors.warning),
      if (low.isNotEmpty) alert(Icons.inventory_2, 'Stock bas : ${low.map((p) => "${p['name']} (${p['stock']})").join(", ")}', AppColors.danger),
      if (maint.isNotEmpty) alert(Icons.build, 'Matériel à vérifier : ${maint.map((e) => e['name']).join(", ")}', AppColors.warning),
    ];
    final renewList = [...expiring, ...lapsed];
    return Scaffold(
      appBar: AppBar(
        title: Text('Administration · ${me.firstName}'),
        actions: [NotificationBell(page: () => const NotificationsPage()), IconButton(tooltip: 'Actualiser', onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.all(12), children: [
            kpiGrid([
                kpiCard(context, Icons.groups, 'Membres', '${st['athletes'] ?? 0}'),
                kpiCard(context, Icons.verified, 'Abonnements actifs', '${st['active'] ?? 0}', color: AppColors.success),
                kpiCard(context, Icons.warning_amber, 'Membres sans abonnement', '${st['expired'] ?? 0}', color: AppColors.warning),
                kpiCard(context, Icons.payments, 'Revenus du mois', '${monthRev.toStringAsFixed(0)} DT'),
                kpiCard(context, Icons.sports, 'Coachs · suivis actifs', '${st['coaches'] ?? 0} · ${st['coachings'] ?? 0}'),
                kpiCard(context, Icons.local_fire_department, 'Séances enregistrées (7 j)', '${st['workouts_7d'] ?? 0}', color: AppColors.ember),
                kpiCard(context, Icons.how_to_reg, 'Présences aujourd\'hui', '${st['checkins_today'] ?? 0}', color: AppColors.info),
                kpiCard(context, Icons.block, 'Comptes désactivés', '${st['disabled'] ?? 0}', color: AppColors.danger),
              ]),
            sectionTitle(context, 'À surveiller'),
            if (alerts.isEmpty) alert(Icons.check_circle_rounded, 'Tout est en ordre ✅', AppColors.success) else ...alerts,
            if (rev.isNotEmpty) ...[
              sectionTitle(context, 'Revenus par mois (DT)'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    height: 170, width: double.infinity,
                    child: CustomPaint(painter: BarsPainter([for (final r in rev) monthShort[int.parse('${r['m']}'.substring(5, 7)) - 1]], [for (final r in rev) num2(r['total'])], cs.primary, cs.onSurface)),
                  ),
                ),
              ),
            ],
            sectionTitle(context, 'Cours aujourd\'hui (${st['bookings'] ?? 0} réservations au total)'),
            if (today.isEmpty) const Card(child: Empty(Icons.event_busy, 'Aucun cours aujourd\'hui')),
            for (final c in today)
              Card(
                child: ListTile(
                  leading: const IconBadge(Icons.schedule_rounded),
                  title: Text('${c['time']} · ${c['title']}'),
                  subtitle: Text('${c['coach_name'] ?? '—'} · ${c['taken']}/${c['spots']} inscrits'),
                  trailing: OutlinedButton(onPressed: () => open(ParticipantsPage(c)), child: const Text('Pointer')),
                ),
              ),
            if (renewList.isNotEmpty) ...[
              sectionTitle(context, 'Abonnements à renouveler'),
              for (final a in renewList)
                Card(
                  child: ListTile(
                    leading: InitialAvatar('${a['name']}'),
                    title: Text('${a['name']}'),
                    subtitle: Text('${'${a['sub_end']}'.compareTo(todayIso()) < 0 ? "Expiré" : "Expire"} le ${a['sub_end']}'),
                    trailing: FilledButton.tonal(onPressed: () => renew(a), child: const Text('Renouveler')),
                  ),
                ),
            ],
            if (fill.isNotEmpty) ...[
              sectionTitle(context, 'Remplissage des cours'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    for (final c in fill)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(children: [
                          SizedBox(width: 120, child: Text('${c['title']} · ${dayShort[((c['day'] ?? 0) as int) % 7]}', overflow: TextOverflow.ellipsis)),
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

// =============== DEMANDES D'ABONNEMENT ===============
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});
  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      list = await AdminService.pendingRequests();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> approve(Map<String, dynamic> r) async {
    final method = await pickMethod(context, 'Paiement reçu de ${r['member_name']} (${money(r['price'])})');
    if (method == null || !mounted) return;
    if (await attempt(context, () => AdminService.approveRequest(r['id'] as int, method), success: 'Abonnement activé, paiement enregistré ✓')) load();
  }

  Future<void> reject(Map<String, dynamic> r) async {
    if (!await confirm(context, 'Refuser la demande de ${r['member_name']} ?', ok: 'Refuser')) return;
    if (mounted && await attempt(context, () => AdminService.rejectRequest(r['id'] as int))) load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Demandes d\'abonnement'), actions: [IconButton(tooltip: 'Actualiser', onPressed: load, icon: const Icon(Icons.refresh))]),
        body: AsyncBody(
          loading: loading,
          error: error,
          onRetry: load,
          builder: () => list.isEmpty
              ? const Empty(Icons.assignment_turned_in, 'Aucune demande en attente')
              : ListView(padding: const EdgeInsets.all(12), children: [
                  for (final r in list)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${r['member_name']}', style: Theme.of(context).textTheme.titleMedium),
                          Text('${r['plan_name']} — ${money(r['price'])} · demandé le ${dateOnly(r['created'])}'),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                            TextButton(onPressed: () => reject(r), child: const Text('Refuser')),
                            const SizedBox(width: 8),
                            FilledButton(onPressed: () => approve(r), child: const Text('Valider (payé)')),
                          ]),
                        ]),
                      ),
                    ),
                ]),
        ),
      );
}

// =============== SUIVIS COACHING (admin) ===============
class CoachingAdminPage extends StatefulWidget {
  const CoachingAdminPage({super.key});
  @override
  State<CoachingAdminPage> createState() => _CoachingAdminPageState();
}

class _CoachingAdminPageState extends State<CoachingAdminPage> {
  static const statuses = {'': 'Tous', 'active': 'Actifs', 'pending': 'En attente', 'ended': 'Terminés', 'declined': 'Refusés'};
  List<Map<String, dynamic>> list = [];
  bool loading = true;
  String? error;
  String status = '';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      list = await AdminService.coachingLinks(status: status);
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> assign() async {
    await Refs.load();
    final coaches = Refs.data['coaches'] ?? [], members = Refs.data['members'] ?? [];
    if (!mounted) return;
    Object? coach, client;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Attribuer un coach'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<Object?>(
              initialValue: coach, isExpanded: true, decoration: const InputDecoration(labelText: 'Coach'),
              items: [for (final c in coaches) DropdownMenuItem(value: c['id'], child: Text('${c['name']} · ${c['specialty'] ?? ''}'))],
              onChanged: (x) => set(() => coach = x),
            ),
            DropdownButtonFormField<Object?>(
              initialValue: client, isExpanded: true, decoration: const InputDecoration(labelText: 'Membre'),
              items: [for (final m in members.where((m) => m['id'] != coach && m['active'] != 0)) DropdownMenuItem(value: m['id'], child: Text('${m['name']} (@${m['login']})'))],
              onChanged: (x) => set(() => client = x),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(d, coach != null && client != null), child: const Text('Attribuer')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (await attempt(context, () => AdminService.assignCoach(coach, client), success: 'Coach attribué ✓')) load();
  }

  Future<void> end(Map<String, dynamic> l) async {
    if (!await confirm(context, 'Mettre fin au suivi ?', body: '${l['coach_name']} → ${l['client_name']}', ok: 'Terminer')) return;
    if (mounted && await attempt(context, () => AdminService.endCoaching(l['id'] as int))) load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Suivis coaching'), actions: [IconButton(tooltip: 'Actualiser', onPressed: load, icon: const Icon(Icons.refresh))]),
        floatingActionButton: FloatingActionButton.extended(onPressed: assign, icon: const Icon(Icons.person_add), label: const Text('Attribuer')),
        body: Column(children: [
          SizedBox(
            height: 56,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), children: [
              for (final e in statuses.entries)
                Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(e.value), selected: status == e.key, onSelected: (_) { setState(() { status = e.key; loading = true; }); load(); })),
            ]),
          ),
          Expanded(
            child: AsyncBody(
              loading: loading,
              error: error,
              onRetry: load,
              builder: () => list.isEmpty
                  ? const Empty(Icons.sports, 'Aucune relation de coaching')
                  : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 88), children: [
                      for (final l in list)
                        Card(
                          child: ListTile(
                            leading: IconBadge(switch (l['status']) { 'active' => Icons.verified_rounded, 'pending' => Icons.hourglass_top_rounded, _ => Icons.history_rounded }, color: switch (l['status']) { 'active' => AppColors.success, 'pending' => AppColors.info, _ => null }),
                            title: Text('${l['coach_name']} → ${l['client_name']}'),
                            subtitle: Text('${statuses[l['status']] ?? l['status']} · depuis le ${dateOnly(l['updated'])}'),
                            trailing: l['status'] == 'active' || l['status'] == 'pending' ? TextButton(onPressed: () => end(l), child: const Text('Terminer')) : null,
                          ),
                        ),
                    ]),
            ),
          ),
        ]),
      );
}
