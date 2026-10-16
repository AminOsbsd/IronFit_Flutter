import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import '../models/module.dart';
import 'planning_screen.dart';

// =============== TABLEAU DE BORD ADMIN / COACH ===============
class StaffHome extends StatefulWidget {
  const StaffHome({super.key});
  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  bool loading = true;
  String? error;
  Map<String, dynamic> st = {};
  List<Map<String, dynamic>> today = [];
  bool get admin => Api.role == 'admin';

  @override
  void initState() {
    super.initState();
    load();
  }

  List<Map<String, dynamic>> L(String k) => ((st[k] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  Future<void> load() async {
    try {
      Api.me = Map<String, dynamic>.from(await Api.call('GET', 'me') as Map);
      st = Map<String, dynamic>.from(await Api.call('GET', 'stats') as Map);
      await Refs.load();
      final dow = DateTime.now().weekday - 1;
      today = (await Api.list('classes')).where((c) => c['day'] == dow && (admin || c['coach_id'] == Api.me!['id'])).toList();
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
              items: [for (final p in plans) DropdownMenuItem<Object?>(value: p['id'], child: Text('${p['name']} — ${p['price']} DT'))],
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
    if (ok != true) return;
    try {
      await Api.call('POST', 'members/${a['id']}/renew', {'plan_id': plan, 'method': method});
      if (mounted) snack(context, 'Abonnement renouvelé, paiement enregistré ✓');
      load();
    } catch (e) {
      snack(context, '$e');
    }
  }

  Widget alert(IconData i, String text, Color c, {VoidCallback? onTap}) => Card(
        child: ListTile(leading: Icon(i, color: c), title: Text(text), trailing: onTap == null ? null : const Icon(Icons.chevron_right), onTap: onTap),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = Api.me!;
    final expiring = L('expiring'), lapsed = L('lapsed'), low = L('lowStock'), maint = L('maintenance'), rev = L('revenue'), fill = L('fill');
    final pending = (st['pending'] ?? 0) as int;
    final month = todayIso().substring(0, 7);
    final monthRev = rev.where((r) => r['m'] == month).fold<double>(0, (s, r) => s + num2(r['total']));
    final alerts = <Widget>[
      if (admin && pending > 0)
        alert(Icons.assignment_ind, '$pending demande${pending > 1 ? "s" : ""} d\'abonnement à valider', cs.primary, onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const RequestsPage()));
          load();
        }),
      if (expiring.isNotEmpty) alert(Icons.timer, '${expiring.length} abonnement${expiring.length > 1 ? "s" : ""} expire${expiring.length > 1 ? "nt" : ""} cette semaine', Colors.orange),
      if (low.isNotEmpty) alert(Icons.inventory_2, 'Stock bas : ${low.map((p) => "${p['name']} (${p['stock']})").join(", ")}', Colors.red),
      if (maint.isNotEmpty) alert(Icons.build, 'Matériel à vérifier : ${maint.map((e) => e['name']).join(", ")}', Colors.orange),
    ];
    final renewList = [...expiring, ...lapsed];
    return Scaffold(
      appBar: AppBar(title: Text('Bonjour, ${'${me['name']}'.split(' ').first} 👋'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Empty(Icons.wifi_off, error!, cta: 'Réessayer', onTap: load)
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    GridView.count(
                      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.9,
                      children: [
                        kpiCard(context, Icons.groups, 'Athlètes', '${st['athletes'] ?? 0}'),
                        kpiCard(context, Icons.verified, 'Abonnements actifs', '${st['active'] ?? 0}', color: Colors.green),
                        kpiCard(context, Icons.warning_amber, 'Inactifs', '${st['expired'] ?? 0}', color: Colors.orange),
                        kpiCard(context, Icons.how_to_reg, 'Présences aujourd\'hui', '${st['checkinsToday'] ?? 0}'),
                        if (admin) kpiCard(context, Icons.payments, 'Revenus du mois', '${monthRev.toStringAsFixed(0)} DT'),
                      ],
                    ),
                    sectionTitle(context, 'À surveiller'),
                    if (alerts.isEmpty) alert(Icons.check_circle, 'Tout est en ordre ✅', Colors.green) else ...alerts,
                    if (admin && rev.isNotEmpty) ...[
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
                    sectionTitle(context, admin ? 'Séances aujourd\'hui' : 'Mes séances aujourd\'hui'),
                    if (today.isEmpty) const Card(child: Empty(Icons.event_busy, 'Aucune séance aujourd\'hui')),
                    for (final c in today)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.schedule),
                          title: Text('${c['time']} · ${c['title']}'),
                          subtitle: Text('${c['coach_name'] ?? '—'} · ${c['taken']}/${c['spots']} inscrits'),
                          trailing: OutlinedButton(onPressed: () async { await Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantsPage(c))); load(); }, child: const Text('Pointer')),
                        ),
                      ),
                    if (renewList.isNotEmpty) ...[
                      sectionTitle(context, 'Abonnements à renouveler'),
                      for (final a in renewList)
                        Card(
                          child: ListTile(
                            leading: const Icon(Icons.person),
                            title: Text('${a['name']}'),
                            subtitle: Text('${'${a['sub_end']}'.compareTo(todayIso()) < 0 ? "Expiré" : "Expire"} le ${a['sub_end']}'),
                            trailing: admin ? FilledButton.tonal(onPressed: () => renew(a), child: const Text('Renouveler')) : null,
                          ),
                        ),
                    ],
                    if (fill.isNotEmpty) ...[
                      sectionTitle(context, 'Remplissage des séances'),
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
    );
  }
}

// =============== DEMANDES D'ABONNEMENT (admin) ===============
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key});
  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    list = await safeList('requests');
    if (mounted) setState(() => loading = false);
  }

  Future<void> approve(Map<String, dynamic> r) async {
    final method = await pickMethod(context, 'Paiement reçu de ${r['member_name']} (${r['price']} DT)');
    if (method == null) return;
    try {
      await Api.call('POST', 'requests/${r['id']}/approve', {'method': method});
      if (mounted) snack(context, 'Abonnement activé, paiement enregistré ✓');
      load();
    } catch (e) {
      snack(context, '$e');
    }
  }

  Future<void> reject(Map<String, dynamic> r) async {
    try {
      await Api.call('POST', 'requests/${r['id']}/reject');
      load();
    } catch (e) {
      snack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Demandes d\'abonnement'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : list.isEmpty
                ? const Empty(Icons.assignment_turned_in, 'Aucune demande en attente')
                : ListView(padding: const EdgeInsets.all(12), children: [
                    for (final r in list)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${r['member_name']}', style: Theme.of(context).textTheme.titleMedium),
                            Text('${r['plan_name']} — ${r['price']} DT · demandé le ${'${r['created']}'.split(' ').first}'),
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
      );
}
