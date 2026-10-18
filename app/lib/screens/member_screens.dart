import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import '../widgets/form_dialog.dart';
import '../models/module.dart';
import 'coaches_screen.dart';
import 'crud_screen.dart';
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
  List<Map<String, dynamic>> classes = [], ann = [], promos = [], reqs = [], measures = [], programs = [], workouts = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      await Api.refreshMe();
      error = null;
    } catch (e) {
      error = '$e';
      if (mounted) setState(() => loading = false);
      return;
    }
    await Refs.load();
    final r = await Future.wait([
      safeList('classes'), safeList('announcements'), safeList('promos'), safeList('requests'), safeList('measures'),
      safeList('programs?scope=personal'), safeList('workouts?limit=50'),
    ]);
    classes = r[0]; ann = r[1]; promos = r[2]; reqs = r[3]; measures = r[4]; programs = r[5]; workouts = r[6];
    Api.refreshUnread();
    if (mounted) setState(() => loading = false);
  }

  Future<void> cancelRequest(int id) async {
    if (await attempt(context, () => Api.call('POST', 'requests/$id/cancel'))) load();
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
        gradient: LinearGradient(colors: [cs.primary, cs.tertiary], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.fitness_center, color: Colors.white),
          const SizedBox(width: 8),
          Text(Api.isCoach ? 'IRONFIT · CARTE MEMBRE · COACH' : 'IRONFIT · CARTE MEMBRE', style: const TextStyle(color: Colors.white70, letterSpacing: 1.2, fontSize: 12)),
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
    final ago7 = DateTime.now().subtract(const Duration(days: 7));
    final week = workouts.where((w) => (DateTime.tryParse('${w['done_on']}') ?? DateTime(2000)).isAfter(ago7)).length;
    final sorted = [...measures]..sort((a, b) => '${b['measured_on']}'.compareTo('${a['measured_on']}'));
    final weight = sorted.where((m) => m['weight'] != null).isEmpty ? '—' : '${sorted.firstWhere((m) => m['weight'] != null)['weight']} kg';
    final offers = promos.where((p) => p['until'] == null || '${p['until']}'.compareTo(today) >= 0).toList();
    final activePrograms = programs.where((p) => p['active'] == 1).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour, ${'${me['name']}'.split(' ').first} 👋'),
        actions: [NotificationBell(page: () => const NotificationsPage()), IconButton(tooltip: 'Actualiser', onPressed: load, icon: const Icon(Icons.refresh))],
      ),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => RefreshIndicator(
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
              Expanded(child: kpiCard(context, Icons.local_fire_department, 'Séances (7 j)', '$week')),
              Expanded(child: kpiCard(context, Icons.event_available, 'Réservations', '${mine.length}')),
              Expanded(child: kpiCard(context, Icons.monitor_weight, 'Poids', weight)),
            ]),
            sectionTitle(context, 'Mes programmes'),
            if (activePrograms.isEmpty)
              Card(child: Empty(Icons.list_alt, 'Aucun programme actif.', cta: 'Créer ou trouver un coach', onTap: () => widget.goTab(3)))
            else
              for (final p in activePrograms.take(3))
                Card(
                  child: ListTile(
                    leading: Icon(p['coach_id'] == null ? Icons.person : Icons.sports),
                    title: Text('${p['title']}'),
                    subtitle: Text('${p['coach_id'] == null ? 'Personnel' : 'Par ${p['coach_name']}'} · ${p['sessions']} séance(s)${p['last_done'] == null ? '' : ' · dernière ${p['last_done']}'}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => ProgramDetailPage(p['id'] as int)));
                      load();
                    },
                  ),
                ),
            sectionTitle(context, 'Mes prochains cours'),
            if (mine.isEmpty)
              Card(child: Empty(Icons.event, 'Aucun cours réservé.', cta: 'Voir le planning', onTap: () => widget.goTab(1)))
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
  List<Map<String, dynamic>> plans = [], promos = [], products = [], ann = [], reqs = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final r = await Future.wait([safeList('plans'), safeList('promos'), safeList('products'), safeList('announcements'), safeList('requests')]);
    plans = r[0]; promos = r[1]; products = r[2]; ann = r[3]; reqs = r[4];
    if (mounted) setState(() => loading = false);
  }

  Future<void> choose(Map<String, dynamic> p) async {
    if (!await confirm(context, 'Demander « ${p['name']} » ?', body: '${p['price']} DT · ${p['duration'] ?? ''}\nL\'abonnement sera activé par l\'administrateur après paiement à l\'accueil.', ok: 'Envoyer la demande')) return;
    if (mounted && await attempt(context, () => Api.call('POST', 'requests', {'plan_id': p['id']}), success: 'Demande envoyée ✓')) load();
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
        child: GridView.extent(
          padding: const EdgeInsets.all(12), maxCrossAxisExtent: 220, childAspectRatio: 1.15, mainAxisSpacing: 8, crossAxisSpacing: 8,
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
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Explorer'),
          bottom: const TabBar(isScrollable: true, tabs: [Tab(text: 'Tarifs'), Tab(text: 'Coachs'), Tab(text: 'Offres'), Tab(text: 'Boutique'), Tab(text: 'Annonces')]),
          actions: [IconButton(tooltip: 'Actualiser', onPressed: load, icon: const Icon(Icons.refresh))],
        ),
        body: loading ? const Center(child: CircularProgressIndicator()) : TabBarView(children: [plansTab(), const CoachesTab(), promosTab(), shopTab(), annTab()]),
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
        item(Icons.list_alt, 'Mes programmes', 'Programmes personnels et programmes de mon coach', const ProgramsPage()),
        item(Icons.local_fire_department, 'Mes séances', 'Historique d\'entraînement et commentaires du coach', const WorkoutHistoryPage()),
        item(Icons.show_chart, 'Ma progression', 'Poids, masse grasse, historique', ProgressPage(memberId: Api.myId!, title: 'Ma progression')),
        item(Icons.sports, 'Mes coachs', 'Suivi en cours et demandes', const MyCoachesPage()),
        item(Icons.how_to_reg, 'Mes présences', 'Mes venues aux cours collectifs', const AttendancePage()),
        item(Icons.receipt_long, 'Mes paiements', 'Historique de mes règlements', CrudPage(moduleById('payments'))),
      ]),
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
  List<Map<String, dynamic>> ms = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final l = await Api.list(Api.withQuery('measures', {'member_id': widget.memberId}));
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
    ], submit: (v) => Api.call('POST', 'measures', {...v, 'member_id': widget.memberId}));
    if (r != null) load();
  }

  @override
  Widget build(BuildContext context) {
    final w = [for (final m in ms) if (m['weight'] != null) num2(m['weight'])];
    final cs = Theme.of(context).colorScheme;
    final delta = w.length >= 2 ? w.last - w.first : 0.0;
    final fat = ms.where((m) => m['body_fat'] != null).toList();
    return AsyncBody(
      loading: loading,
      error: error,
      onRetry: load,
      builder: () => RefreshIndicator(
        onRefresh: load,
        child: ListView(padding: const EdgeInsets.all(12), physics: const AlwaysScrollableScrollPhysics(), children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: add, icon: const Icon(Icons.add), label: const Text('Ajouter une mesure'))),
          if (ms.isEmpty)
            const Empty(Icons.show_chart, 'Aucune mesure pour le moment.')
          else ...[
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
          ],
        ]),
      ),
    );
  }
}

class ProgressPage extends StatelessWidget {
  final int memberId;
  final String title;
  const ProgressPage({super.key, required this.memberId, required this.title});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)), body: ProgressView(memberId: memberId));
}

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
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
      final l = await Api.list(Api.withQuery('checkins', {'member_id': Api.myId}));
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
            ? const Empty(Icons.how_to_reg, 'Aucune présence enregistrée.\nVos venues sont pointées par le coach pendant les cours.')
            : ListView(padding: const EdgeInsets.all(12), children: [
                Row(children: [
                  Expanded(child: kpiCard(context, Icons.calendar_month, 'Ce mois', '${list.where((c) => '${c['checkin_on']}'.startsWith(month)).length}')),
                  Expanded(child: kpiCard(context, Icons.emoji_events, 'Total', '${list.length}')),
                  Expanded(child: kpiCard(context, Icons.history, 'Dernière venue', '${list.first['checkin_on'] ?? '—'}'.replaceFirst(RegExp(r'^\d{4}-'), ''))),
                ]),
                sectionTitle(context, 'Historique'),
                for (final c in list) Card(child: ListTile(leading: const Icon(Icons.check_circle, color: Colors.green), title: Text('${c['note'] ?? 'Entraînement'}'), subtitle: Text('${c['checkin_on'] ?? '—'}'))),
              ]),
      ),
    );
  }
}
