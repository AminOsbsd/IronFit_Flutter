import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';
import 'crud_screen.dart';
import '../models/module.dart';

/// Planning hebdomadaire : puces de jours + séances du jour choisi.
/// Athlète : réserver / annuler. Coach & admin : participants et pointage.
class PlanningPage extends StatefulWidget {
  const PlanningPage({super.key});
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  int day = DateTime.now().weekday - 1;
  List<Map<String, dynamic>> classes = [];
  bool loading = true;
  String? error;
  bool get staff => Api.role != 'athlete';

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      classes = await Api.list('classes');
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> book(Map<String, dynamic> c) async {
    try {
      await Api.call('POST', 'book', {'class_id': c['id']});
      await load();
    } catch (e) {
      snack(context, '$e');
    }
  }

  Widget tile(Map<String, dynamic> c) {
    final taken = num2(c['taken']), spots = num2(c['spots']), mine = isTrue(c['mine']), full = taken >= spots && !mine;
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Text('${c['time']}', style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c['title']}', style: t.titleMedium),
              Text('Coach : ${c['coach_name'] ?? '—'}', style: t.bodySmall),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: spots == 0 ? 0 : (taken / spots).clamp(0.0, 1.0).toDouble(), minHeight: 6, borderRadius: BorderRadius.circular(3)),
              Text('${taken.toInt()}/${spots.toInt()} places', style: t.bodySmall),
            ]),
          ),
          const SizedBox(width: 12),
          if (staff)
            OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantsPage(c))), child: const Text('Participants'))
          else if (mine)
            OutlinedButton(onPressed: () => book(c), child: const Text('Annuler'))
          else
            FilledButton(onPressed: full ? null : () => book(c), child: Text(full ? 'Complet' : 'Réserver')),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday - 1;
    final list = classes.where((c) => c['day'] == day).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Planning'), actions: [
        if (staff)
          IconButton(
            tooltip: 'Gérer les séances',
            icon: const Icon(Icons.edit_calendar),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => CrudPage(moduleById('classes'))));
              load();
            },
          ),
        IconButton(onPressed: load, icon: const Icon(Icons.refresh)),
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Empty(Icons.wifi_off, error!, cta: 'Réessayer', onTap: load)
              : Column(children: [
                  SizedBox(
                    height: 56,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      itemCount: 7,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final n = classes.where((c) => c['day'] == i).length;
                        return ChoiceChip(label: Text('${dayShort[i]}${i == today ? " •" : ""}${n > 0 ? "  $n" : ""}'), selected: day == i, onSelected: (_) => setState(() => day = i));
                      },
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: load,
                      child: list.isEmpty
                          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 60), Empty(Icons.event_busy, 'Aucune séance ce jour')])
                          : ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(12, 0, 12, 16), itemCount: list.length, itemBuilder: (_, i) => tile(list[i])),
                    ),
                  ),
                ]),
    );
  }
}

/// Liste des athlètes inscrits à une séance + pointage de présence (le jour même).
class ParticipantsPage extends StatefulWidget {
  final Map<String, dynamic> cls;
  const ParticipantsPage(this.cls, {super.key});
  @override
  State<ParticipantsPage> createState() => _ParticipantsPageState();
}

class _ParticipantsPageState extends State<ParticipantsPage> {
  List<Map<String, dynamic>> list = [];
  bool loading = true;
  bool get isToday => widget.cls['day'] == DateTime.now().weekday - 1;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    list = await safeList('classes/${widget.cls['id']}/participants');
    if (mounted) setState(() => loading = false);
  }

  Future<void> mark(Map<String, dynamic> p) async {
    try {
      await Api.call('POST', 'classes/${widget.cls['id']}/present', {'member_id': p['id']});
      await load();
    } catch (e) {
      snack(context, '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = list.where((p) => isTrue(p['present'])).length;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.cls['title']} · ${widget.cls['time']}')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.secondaryContainer,
                padding: const EdgeInsets.all(12),
                child: Text(isToday ? '$present / ${list.length} présents aujourd\'hui' : 'Le pointage est possible uniquement le jour de la séance (${dayLabel(widget.cls['day'] as int)}).'),
              ),
              Expanded(
                child: list.isEmpty
                    ? const Empty(Icons.people_outline, 'Aucune réservation pour cette séance')
                    : ListView(padding: const EdgeInsets.all(12), children: [
                        for (final p in list)
                          Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Text('${p['name']}'[0].toUpperCase())),
                              title: Text('${p['name']}'),
                              subtitle: Text('${p['phone'] ?? 'Pas de téléphone'}'),
                              trailing: isTrue(p['present'])
                                  ? const Chip(avatar: Icon(Icons.check_circle, color: Colors.green), label: Text('Présent'))
                                  : FilledButton.tonal(onPressed: isToday ? () => mark(p) : null, child: const Text('Pointer')),
                            ),
                          ),
                      ]),
              ),
            ]),
    );
  }
}
