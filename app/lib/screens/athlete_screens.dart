import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'crud_screen.dart';
import '../models/module.dart';

// =============== ACCUEIL ATHLÈTE ===============
class AthleteHome extends StatefulWidget {
  final void Function(int) goTab;
  const AthleteHome({super.key, required this.goTab});
  @override
  State<AthleteHome> createState() => _AthleteHomeState();
}

class _AthleteHomeState extends State<AthleteHome> {
  bool loading = true;
  List<Map<String, dynamic>> classes = [], ann = [], promos = [], reqs = [], checkins = [], measures = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      Api.me = Map<String, dynamic>.from(await Api.call('GET', 'me') as Map);
    } catch (_) {}
    await Refs.load();
    classes = await safeList('classes');
    ann = await safeList('announcements');
    promos = await safeList('promos');
    reqs = await safeList('requests');
    checkins = await safeList('checkins');
    measures = await safeList('measures');
    if (mounted) setState(() => loading = false);
  }

  Future<void> cancelRequest(int id) async {
    try {
      await Api.call('POST', 'requests/$id/cancel');
      load();
    } catch (e) {
      snack(context, '$e');
    }
  }

  Widget memberCard() {
    final me = Api.me!, end = me['sub_end'] as String?, cs = Theme.of(context).colorScheme;
    final active = end != null && end.compareTo(todayIso()) >= 0;
    final left = end == null ? 0 : DateTime.parse(end).difference(DateTime.now()).inDays + 1;
    final status = end == null ? 'Aucun abonnement' : (active ? 'Actif · $left jour${left > 1 ? "s" : ""} restant${left > 1 ? "s" : ""}' : 'Expiré le $end');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(colors: active ? const [Color(0xFFFF5A1F), Color(0xFFFF9A3C)] : [cs.outline, cs.outlineVariant]),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.fitness_center, color: Colors.white),
          const SizedBox(width: 8),
          const Text('IRONFIT · CARTE MEMBRE', style: TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 12)),
        ]),
        const SizedBox(height: 18),
        Text('${me['name']}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        Text('N° ${'${me['id']}'.padLeft(4, '0')} · ${me['plan_id'] == null ? '—' : Refs.name('plans', me['plan_id'])}', style: const TextStyle(color: Colors.white)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(20)),
          child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = Api.me!, end = me['sub_end'] as String?, today = todayIso();
    final active = end != null && end.compareTo(today) >= 0;
    final pending = reqs.where((r) => r['status'] == 'pending').toList();
    final dow = DateTime.now().weekday - 1;
    final mine = classes.where((c) => isTrue(c['mine'])).toList()
      ..sort((a, b) {
        final ka = (((a['day'] as int) - dow) + 7) % 7, kb = (((b['day'] as int) - dow) + 7) % 7;
        return ka != kb ? ka.compareTo(kb) : '${a['time']}'.compareTo('${b['time']}');
      });
    final month = today.substring(0, 7);
    final visits = checkins.where((c) => '${c['checkin_on']}'.startsWith(month)).length;
    final sorted = [...measures]..sort((a, b) => '${b['measured_on']}'.compareTo('${a['measured_on']}'));
    final weight = sorted.where((m) => m['weight'] != null).isEmpty ? '—' : '${sorted.firstWhere((m) => m['weight'] != null)['weight']} kg';
    final offers = promos.where((p) => p['until'] == null || '${p['until']}'.compareTo(today) >= 0).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Bonjour, ${'${me['name']}'.split(' ').first} 👋'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.all(12), children: [
                memberCard(),
                if (pending.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(top: 10),
                    child: ListTile(
                      leading: const Icon(Icons.hourglass_top),
                      title: Text('Demande en attente : ${pending.first['plan_name']}'),
                      subtitle: const Text('Réglez à l\'accueil : l\'abonnement sera activé par l\'administrateur.'),
                      trailing: TextButton(onPressed: () => cancelRequest(pending.first['id'] as int), child: const Text('Annuler')),
                    ),
                  )
                else if (!active)
                  Card(
                    margin: const EdgeInsets.only(top: 10),
                    color: Theme.of(context).colorScheme.tertiaryContainer,
                    child: ListTile(
                      leading: const Icon(Icons.card_membership),
                      title: Text(end == null ? 'Pas encore d\'abonnement' : 'Votre abonnement a expiré'),
                      subtitle: const Text('Choisissez une formule pour réserver vos séances.'),
                      trailing: FilledButton(onPressed: () => widget.goTab(2), child: const Text('Choisir')),
                    ),
                  ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: kpiCard(context, Icons.how_to_reg, 'Présences (mois)', '$visits')),
                  Expanded(child: kpiCard(context, Icons.event_available, 'Réservations', '${mine.length}')),
                  Expanded(child: kpiCard(context, Icons.monitor_weight, 'Poids', weight)),
                ]),
                sectionTitle(context, 'Mes prochaines séances'),
                if (mine.isEmpty)
                  Card(child: Empty(Icons.event, 'Aucune séance réservée.', cta: 'Voir le planning', onTap: () => widget.goTab(1)))
                else
                  for (final c in mine.take(3))
                    Card(child: ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: Text('${c['title']}'), subtitle: Text('${dayLabel(c['day'] as int)} · ${c['time']} · ${c['coach_name'] ?? '—'}'))),
                if (ann.isNotEmpty) sectionTitle(context, 'Annonces'),
                for (final a in ann.take(2)) Card(child: ListTile(leading: const Icon(Icons.campaign), title: Text('${a['title']}'), subtitle: Text('${a['body'] ?? ''}'))),
                if (offers.isNotEmpty)
                  InkWell(
                    onTap: () => widget.goTab(2),
                    child: Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Theme.of(context).colorScheme.primaryContainer),
                      child: Row(children: [
                        const Icon(Icons.local_offer, size: 32),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${offers.first['title']} · -${offers.first['discount'] ?? 0}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${offers.first['descr'] ?? ''}'),
                        ])),
                      ]),
                    ),
                  ),
              ]),
            ),
    );
  }
}

// =============== EXPLORER : tarifs, offres, boutique, annonces ===============
class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});
  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  bool loading = true;
  List<Map<String, dynamic>> plans = [], promos = [], products = [], ann = [], reqs = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    plans = await safeList('plans');
    promos = await safeList('promos');
    products = await safeList('products');
    ann = await safeList('announcements');
    reqs = await safeList('requests');
    if (mounted) setState(() => loading = false);
  }

  Future<void> choose(Map<String, dynamic> p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Demander « ${p['name']} » ?'),
        content: Text('${p['price']} DT · ${p['duration'] ?? ''}\nL\'abonnement sera activé par l\'administrateur après paiement à l\'accueil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Envoyer la demande')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.call('POST', 'requests', {'plan_id': p['id']});
      if (mounted) snack(context, 'Demande envoyée ✓');
      load();
    } catch (e) {
      snack(context, '$e');
    }
  }

  Widget plansTab() {
    if (plans.isEmpty) return const Empty(Icons.credit_card_off, 'Aucun tarif disponible pour le moment');
    final pending = reqs.where((r) => r['status'] == 'pending').toList();
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final p in plans)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${p['name']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                if (Api.me!['plan_id'] == p['id']) const Chip(label: Text('Mon offre')),
              ]),
              Text('${p['price']} DT', style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.bold)),
              Text('${p['duration'] ?? ''}'),
              if ((p['descr'] ?? '') != '') Padding(padding: const EdgeInsets.only(top: 4), child: Text('${p['descr']}')),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: pending.isNotEmpty ? null : () => choose(p),
                  child: Text(pending.any((r) => r['plan_id'] == p['id']) ? 'Demande envoyée' : (Api.me!['plan_id'] == p['id'] ? 'Renouveler' : 'Choisir')),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget promosTab() {
    if (promos.isEmpty) return const Empty(Icons.local_offer_outlined, 'Aucune offre en ce moment');
    final today = todayIso();
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final p in promos)
        Builder(builder: (_) {
          final expired = p['until'] != null && '${p['until']}'.compareTo(today) < 0;
          return Card(
            child: ListTile(
              leading: CircleAvatar(backgroundColor: expired ? Colors.grey : Theme.of(context).colorScheme.primary, foregroundColor: Colors.white, child: Text('-${p['discount'] ?? 0}%', style: const TextStyle(fontSize: 11))),
              title: Text('${p['title']}'),
              subtitle: Text('${p['descr'] ?? ''}\n${expired ? "Expirée" : "Valable jusqu'au ${p['until'] ?? '—'}"}'),
              isThreeLine: true,
            ),
          );
        }),
    ]);
  }

  Widget shopTab() {
    if (products.isEmpty) return const Empty(Icons.storefront, 'La boutique est vide');
    return Column(children: [
      const Padding(padding: EdgeInsets.all(8), child: Text('Achat directement à l\'accueil de la salle.', style: TextStyle(fontSize: 12))),
      Expanded(
        child: GridView.count(
          padding: const EdgeInsets.all(12), crossAxisCount: 2, childAspectRatio: 1.15, mainAxisSpacing: 8, crossAxisSpacing: 8,
          children: [
            for (final p in products)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.shopping_bag_outlined, size: 30),
                    Text('${p['name']}', textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${p['price']} DT', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    Text(num2(p['stock']) <= 0 ? 'Rupture' : (num2(p['stock']) <= 5 ? 'Stock limité' : 'Disponible'), style: const TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget annTab() => ann.isEmpty
      ? const Empty(Icons.campaign_outlined, 'Aucune annonce')
      : ListView(padding: const EdgeInsets.all(12), children: [
          for (final a in ann) Card(child: ListTile(leading: const Icon(Icons.campaign), title: Text('${a['title']}'), subtitle: Text('${a['posted_on'] ?? ''}\n${a['body'] ?? ''}'), isThreeLine: true)),
        ]);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Explorer'),
          bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Tarifs'), Tab(text: 'Offres'), Tab(text: 'Boutique'), Tab(text: 'Annonces')]),
          actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))],
        ),
        body: loading ? const Center(child: CircularProgressIndicator()) : TabBarView(children: [plansTab(), promosTab(), shopTab(), annTab()]),
      ),
    );
  }
}

// =============== MON ESPACE ===============
class MySpacePage extends StatelessWidget {
  const MySpacePage({super.key});
  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, String s, Widget page) => Card(
          child: ListTile(leading: Icon(i), title: Text(t), subtitle: Text(s), trailing: const Icon(Icons.chevron_right), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page))),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Mon espace')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        item(Icons.show_chart, 'Ma progression', 'Poids, masse grasse, historique', const ProgressPage()),
        item(Icons.how_to_reg, 'Mes présences', 'Mes entraînements et ma régularité', const AttendancePage()),
        item(Icons.receipt_long, 'Mes paiements', 'Historique de mes règlements', CrudPage(moduleById('payments'))),
      ]),
    );
  }
}

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  List<Map<String, dynamic>> ms = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    safeList('measures').then((l) {
      l.sort((a, b) => '${a['measured_on']}'.compareTo('${b['measured_on']}'));
      if (mounted) setState(() { ms = l; loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = [for (final m in ms) if (m['weight'] != null) num2(m['weight'])];
    final cs = Theme.of(context).colorScheme;
    final delta = w.length >= 2 ? w.last - w.first : 0.0;
    final fat = ms.where((m) => m['body_fat'] != null).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Ma progression')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ms.isEmpty
              ? const Empty(Icons.show_chart, 'Aucune mesure pour le moment.\nVotre coach en ajoutera lors de votre bilan.')
              : ListView(padding: const EdgeInsets.all(12), children: [
                  Row(children: [
                    Expanded(child: kpiCard(context, Icons.monitor_weight, 'Poids actuel', w.isEmpty ? '—' : '${w.last} kg')),
                    Expanded(child: kpiCard(context, delta <= 0 ? Icons.trending_down : Icons.trending_up, 'Évolution', '${delta > 0 ? "+" : ""}${delta.toStringAsFixed(1)} kg')),
                    Expanded(child: kpiCard(context, Icons.percent, 'Masse grasse', fat.isEmpty ? '—' : '${fat.last['body_fat']} %')),
                  ]),
                  if (w.length >= 2)
                    Card(child: Padding(padding: const EdgeInsets.all(12), child: SizedBox(height: 180, width: double.infinity, child: CustomPaint(painter: LinePainter(w, cs.primary, cs.onSurface))))),
                  sectionTitle(context, 'Historique'),
                  for (final m in ms.reversed)
                    Card(child: ListTile(title: Text('${m['weight'] ?? '—'} kg · ${m['body_fat'] ?? '—'} % MG'), subtitle: Text('${m['measured_on'] ?? '—'} · ${m['note'] ?? ''}'))),
                ]),
    );
  }
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    safeList('checkins').then((l) {
      l.sort((a, b) => '${b['checkin_on']}'.compareTo('${a['checkin_on']}'));
      if (mounted) setState(() { list = l; loading = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final month = todayIso().substring(0, 7);
    return Scaffold(
      appBar: AppBar(title: const Text('Mes présences')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : list.isEmpty
              ? const Empty(Icons.how_to_reg, 'Aucune présence enregistrée.\nVos venues sont pointées par le coach pendant les séances.')
              : ListView(padding: const EdgeInsets.all(12), children: [
                  Row(children: [
                    Expanded(child: kpiCard(context, Icons.calendar_month, 'Ce mois', '${list.where((c) => '${c['checkin_on']}'.startsWith(month)).length}')),
                    Expanded(child: kpiCard(context, Icons.emoji_events, 'Total', '${list.length}')),
                    Expanded(child: kpiCard(context, Icons.history, 'Dernière venue', '${list.first['checkin_on'] ?? '—'}'.replaceFirst(RegExp(r'^\d{4}-'), ''))),
                  ]),
                  sectionTitle(context, 'Historique'),
                  for (final c in list) Card(child: ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: Text('${c['note'] ?? 'Entraînement'}'), subtitle: Text('${c['checkin_on'] ?? '—'}'))),
                ]),
    );
  }
}
