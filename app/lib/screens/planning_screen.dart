import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../models/module.dart';
import '../services/planning_service.dart';
import '../services/user_service.dart' show Json;
import '../widgets/common_widgets.dart';
import 'crud_screen.dart';

/// Planning hebdomadaire : sélecteur de jour + cours du jour choisi.
/// [manage] = false : réserver / annuler (membre, ou coach dans son espace perso).
/// [manage] = true : participants et pointage (admin : tous les cours ; coach : ses cours).
class PlanningPage extends StatefulWidget {
  final bool manage;
  const PlanningPage({super.key, this.manage = false});
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> {
  int day = DateTime.now().weekday - 1;
  List<Json> classes = [];
  bool loading = true;
  String? error;
  bool get manage => widget.manage;
  bool mineToRun(Json c) => Api.isAdmin || c['coach_id'] == Api.myId;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      classes = await PlanningService.classes();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> book(Json c) async {
    if (await attempt(context, () => PlanningService.toggleBooking(c['id'] as int))) await load();
  }

  Widget action(Json c, bool mine, bool full) {
    if (manage) {
      if (!mineToRun(c)) return const SizedBox.shrink();
      return OutlinedButton.icon(
        icon: const Icon(Icons.groups_rounded, size: 18),
        label: const Text('Participants'),
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ParticipantsPage(c)));
          load();
        },
      );
    }
    if (c['coach_id'] == Api.myId) return const StatusPill('Vous animez', color: AppColors.info, icon: Icons.sports_rounded);
    if (mine) return OutlinedButton(onPressed: () => book(c), child: const Text('Annuler'));
    return FilledButton(onPressed: full ? null : () => book(c), child: Text(full ? 'Complet' : 'Réserver'));
  }

  Widget tile(Json c) {
    final taken = num2(c['taken']), spots = num2(c['spots']), mine = isTrue(c['mine']), full = taken >= spots && !mine;
    final ratio = spots == 0 ? 0.0 : (taken / spots).clamp(0.0, 1.0).toDouble();
    final t = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    final barColor = ratio >= 1 ? AppColors.danger : (ratio >= 0.8 ? AppColors.warning : cs.primary);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 68,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: mine ? AppColors.amber : cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(children: [
              Text('${c['time']}', style: t.titleMedium?.copyWith(color: mine ? AppColors.ink : cs.onSurface, fontWeight: FontWeight.w800)),
              if (mine) const Text('Réservé', style: TextStyle(color: AppColors.ink, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${c['title']}', style: t.titleMedium),
              Text('Coach : ${c['coach_name'] ?? '—'}${c['coach_specialty'] == null ? '' : ' · ${c['coach_specialty']}'}', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 8),
              LinearProgressIndicator(value: ratio, minHeight: 6, color: barColor, borderRadius: BorderRadius.circular(3)),
              const SizedBox(height: 4),
              Text('${taken.toInt()}/${spots.toInt()} places', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
          ),
          const SizedBox(width: 12),
          action(c, mine, full),
        ]),
      ),
    );
  }

  Widget dayChip(int i, int today) {
    final n = classes.where((c) => c['day'] == i).length;
    final selected = day == i;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => day = i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.amber : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? AppColors.amber : (i == today ? cs.primary : cs.outlineVariant), width: i == today && !selected ? 1.5 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(dayShort[i], style: TextStyle(fontWeight: FontWeight.w800, color: selected ? AppColors.ink : cs.onSurface)),
            const SizedBox(height: 2),
            Text(n == 0 ? '—' : '$n cours', style: TextStyle(fontSize: 11, color: selected ? AppColors.ink : cs.onSurfaceVariant)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday - 1;
    final list = classes.where((c) => c['day'] == day).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Planning'), actions: [
        if (manage)
          IconButton(
            tooltip: 'Gérer les séances',
            icon: const Icon(Icons.edit_calendar_rounded),
            onPressed: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => CrudPage(moduleById('classes'))));
              load();
            },
          ),
        IconButton(tooltip: 'Actualiser', onPressed: load, icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => Column(children: [
          SizedBox(
            height: 76,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), children: [for (var i = 0; i < 7; i++) dayChip(i, today)]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(alignment: Alignment.centerLeft, child: SectionHeader(dayLabel(day))),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: load,
              child: list.isEmpty
                  ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: const [SizedBox(height: 40), Empty(Icons.event_busy_rounded, 'Aucun cours ce jour')])
                  : ListView.builder(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), itemCount: list.length, itemBuilder: (_, i) => tile(list[i])),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Liste des membres inscrits à un cours + pointage de présence (le jour même).
class ParticipantsPage extends StatefulWidget {
  final Json cls;
  const ParticipantsPage(this.cls, {super.key});
  @override
  State<ParticipantsPage> createState() => _ParticipantsPageState();
}

class _ParticipantsPageState extends State<ParticipantsPage> {
  List<Json> list = [];
  bool loading = true;
  String? error;
  bool get isToday => widget.cls['day'] == DateTime.now().weekday - 1;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      list = await PlanningService.participants(widget.cls['id'] as int);
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> mark(Json p) async {
    if (await attempt(context, () => PlanningService.markPresent(widget.cls['id'] as int, p['id'] as int))) await load();
  }

  @override
  Widget build(BuildContext context) {
    final present = list.where((p) => isTrue(p['present'])).length;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.cls['title']} · ${widget.cls['time']}')),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: isToday ? cs.primaryContainer : cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Icon(isToday ? Icons.how_to_reg_rounded : Icons.info_outline_rounded, color: isToday ? cs.onPrimaryContainer : cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isToday ? '$present / ${list.length} présents aujourd\'hui' : 'Le pointage est possible uniquement le jour du cours (${dayLabel(widget.cls['day'] as int)}).',
                  style: TextStyle(fontWeight: FontWeight.w600, color: isToday ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          if (list.isEmpty) const Empty(Icons.people_outline_rounded, 'Aucune réservation pour ce cours'),
          for (final p in list)
            Card(
              child: ListTile(
                leading: InitialAvatar('${p['name']}'),
                title: Text('${p['name']}'),
                subtitle: Text('${p['phone'] ?? 'Pas de téléphone'}'),
                trailing: isTrue(p['present'])
                    ? const StatusPill('Présent', color: AppColors.success, icon: Icons.check_rounded)
                    : FilledButton(onPressed: isToday ? () => mark(p) : null, child: const Text('Pointer')),
              ),
            ),
        ]),
      ),
    );
  }
}
