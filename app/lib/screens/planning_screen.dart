import '../widgets/member_design.dart';
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
  final bool reservationsOnly;
  const PlanningPage({
    super.key,
    this.manage = false,
    this.reservationsOnly = false,
  });
  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage>
    with WidgetsBindingObserver {
  int day = DateTime.now().weekday - 1;
  DateTime week = DateTime.now().subtract(
    Duration(days: DateTime.now().weekday - 1),
  );
  String iso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  int requestVersion = 0;
  String search = '';
  final searchController = TextEditingController();
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    super.dispose();
  }

  bool onlyMine = false;
  int reservationFilter = 0;
  final Set<int> pending = {};
  final Set<int> uncertain = {};
  List<Json> classes = [];
  bool loading = true;
  String? error;
  bool get manage => widget.manage;
  bool mineToRun(Json c) => Api.isAdmin || c['coach_id'] == Api.myId;

  @override
  void initState() {
    super.initState();
    onlyMine = widget.reservationsOnly;
    WidgetsBinding.instance.addObserver(this);
    load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) load();
  }

  Future<void> load() async {
    final version = ++requestVersion;
    try {
      final result = await PlanningService.classes(week: iso(week));
      if (!mounted || version != requestVersion) return;
      classes = result;
      uncertain.clear();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> book(Json c) async {
    final id = c['id'] as int;
    if (pending.contains(id) || uncertain.contains(id)) return;
    setState(() => pending.add(id));
    try {
      final wasBooked = isTrue(c['mine']);
      if (wasBooked &&
          !await confirm(
            context,
            'Annuler votre réservation ?',
            body:
                '${c['title']} · ${c['session_date'] ?? dayLabel(c['day'] as int)} à ${c['time']}',
            ok: 'Annuler la réservation',
          ))
        return;
      if (!mounted) return;
      try {
        await PlanningService.toggleBooking(
          id,
          date: c['session_date'] as String?,
          booked: !wasBooked,
        );
        if (!mounted) return;
        c['mine'] = !wasBooked;
        c['taken'] = (num2(c['taken']) + (wasBooked ? -1 : 1))
            .clamp(0, double.infinity)
            .toInt();
        snack(
          context,
          wasBooked
              ? 'Réservation annulée'
              : 'Réservation confirmée · ${c['title']} à ${c['time']}',
        );
      } catch (_) {
        // A timeout may happen after the server committed the toggle.
        // Require a successful refresh before allowing another toggle.
        uncertain.add(id);
        if (mounted)
          snack(
            context,
            'Confirmation indisponible. Actualisez le planning avant de réessayer.',
          );
      }
      await load();
    } finally {
      if (mounted) setState(() => pending.remove(id));
    }
  }

  Widget action(Json c, bool mine, bool full) {
    if (pending.contains(c['id']))
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          semanticsLabel: 'Mise à jour de la réservation',
        ),
      );
    if (uncertain.contains(c['id'])) return const Text('À vérifier');
    if (manage) {
      if (!mineToRun(c)) return const SizedBox.shrink();
      return OutlinedButton.icon(
        icon: const Icon(Icons.groups_rounded, size: 18),
        label: const Text('Participants'),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ParticipantsPage(c)),
          );
          load();
        },
      );
    }
    if (c['coach_id'] == Api.myId)
      return const StatusPill(
        'Vous animez',
        color: AppColors.info,
        icon: Icons.sports_rounded,
      );
    final date = DateTime.tryParse('${c['session_date']} ${c['time']}:00');
    if (mine) {
      final status = c['attendance_status'] ?? 'pending';
      if (status != 'pending' ||
          (date != null && date.isBefore(DateTime.now()))) {
        return StatusPill(
          status == 'present'
              ? 'Présence confirmée'
              : status == 'absent'
              ? 'Absent'
              : 'À vérifier',
          color: status == 'present'
              ? AppColors.success
              : status == 'absent'
              ? AppColors.danger
              : AppColors.warning,
        );
      }
    }
    if (!mine && date != null && date.isBefore(DateTime.now()))
      return const Text('Terminée');
    if (mine)
      return OutlinedButton(
        onPressed: () => book(c),
        child: const Text('Annuler'),
      );
    return FilledButton(
      onPressed: full ? null : () => book(c),
      child: Text(full ? 'Complet' : 'Réserver'),
    );
  }

  Widget tile(Json c) {
    final taken = num2(c['taken']),
        spots = num2(c['spots']),
        mine = isTrue(c['mine']),
        full = taken >= spots && !mine;
    final ratio = spots == 0 ? 0.0 : (taken / spots).clamp(0.0, 1.0).toDouble();
    final t = Theme.of(context).textTheme, cs = Theme.of(context).colorScheme;
    final barColor = ratio >= 1
        ? AppColors.danger
        : (ratio >= 0.8 ? AppColors.warning : cs.primary);
    if (isMemberDesign && !manage) {
      return MemberSessionCard(session: c, action: action(c, mine, full));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 68,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: mine ? AppColors.amber : cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${c['time']}',
                        style: t.titleMedium?.copyWith(
                          color: mine ? AppColors.ink : cs.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (mine)
                        const Text(
                          'Réservé',
                          style: TextStyle(
                            color: AppColors.ink,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${c['title']}', style: t.titleMedium),
                      Text(
                        'Coach : ${c['coach_name'] ?? '—'}${c['coach_specialty'] == null ? '' : ' · ${c['coach_specialty']}'}',
                        style: t.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: ratio,
                        minHeight: 6,
                        color: barColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${taken.toInt()}/${spots.toInt()} places',
                        style: t.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: action(c, mine, full),
            ),
          ],
        ),
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
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.amber : cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.amber
                  : (i == today ? cs.primary : cs.outlineVariant),
              width: i == today && !selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dayShort[i],
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: selected ? AppColors.ink : cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                n == 0 ? '—' : '$n cours',
                style: TextStyle(
                  fontSize: 11,
                  color: selected ? AppColors.ink : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planningLayout({required List<Widget> children}) {
    if (!isMemberDesign) return Column(children: children);
    final results = (children.last as Expanded).child;
    return NestedScrollView(
      headerSliverBuilder: (context, scrolled) => [
        SliverToBoxAdapter(
          child: Column(children: children.sublist(0, children.length - 1)),
        ),
      ],
      body: results,
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday - 1;
    final query = search.trim().toLowerCase();
    final list =
        classes
            .where(
              (c) =>
                  (widget.reservationsOnly
                      ? reservationFilter != 2 &&
                            ((DateTime.tryParse(
                                      '${c['session_date']}T${c['time']}',
                                    )?.isBefore(DateTime.now()) ??
                                    false) ==
                                (reservationFilter == 1))
                      : c['day'] == day) &&
                  (!onlyMine || isTrue(c['mine'])) &&
                  '${c['title']} ${c['coach_name'] ?? ''}'
                      .toLowerCase()
                      .contains(query),
            )
            .toList()
          ..sort((a, b) {
            if (widget.reservationsOnly) {
              final byDate = '${a['session_date'] ?? ''}'.compareTo(
                '${b['session_date'] ?? ''}',
              );
              if (byDate != 0) return byDate;
            }
            return '${a['time']}'.compareTo('${b['time']}');
          });
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reservationsOnly ? 'Mes réservations' : 'Planning'),
        actions: [
          if (isMemberDesign && !manage)
            IconButton(
              tooltip: 'Choisir une date',
              icon: const Icon(Icons.calendar_month_outlined),
              onPressed: pending.isNotEmpty
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: week.add(Duration(days: day)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selected == null || !mounted) return;
                      setState(() {
                        day = selected.weekday - 1;
                        week = selected.subtract(Duration(days: day));
                        loading = true;
                      });
                      await load();
                    },
            ),
          if (manage)
            IconButton(
              tooltip: 'Gérer les séances',
              icon: const Icon(Icons.edit_calendar_rounded),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CrudPage(moduleById('classes')),
                  ),
                );
                load();
              },
            ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => _planningLayout(
          children: [
            if (!manage &&
                !Api.isCoach &&
                !Api.isAdmin &&
                !widget.reservationsOnly)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Trouvez votre rythme',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Réservez, participez, progressez.',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ExcludeSemantics(
                      child: Image.asset(
                        'assets/images/member_fitness_3d.png',
                        width: 82,
                        height: 72,
                        cacheWidth: 180,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextFormField(
                controller: searchController,
                decoration: const InputDecoration(
                  labelText: 'Rechercher un cours ou un coach',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (value) => setState(() => search = value),
              ),
            ),
            if (widget.reservationsOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                        label: Text(['À venir', 'Passées', 'Annulées'][i]),
                        selected: reservationFilter == i,
                        onSelected: (_) =>
                            setState(() => reservationFilter = i),
                      ),
                  ],
                ),
              ),
            if (!manage && !widget.reservationsOnly)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    label: const Text('Mes réservations'),
                    selected: onlyMine,
                    onSelected: (value) => setState(() => onlyMine = value),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  tooltip: 'Semaine précédente',
                  onPressed: pending.isNotEmpty
                      ? null
                      : () {
                          setState(() {
                            week = week.subtract(const Duration(days: 7));
                            loading = true;
                          });
                          load();
                        },
                  icon: const Icon(Icons.chevron_left),
                ),
                Flexible(child: Text('Semaine du ${iso(week)}')),
                IconButton(
                  tooltip: 'Semaine suivante',
                  onPressed: pending.isNotEmpty
                      ? null
                      : () {
                          setState(() {
                            week = week.add(const Duration(days: 7));
                            loading = true;
                          });
                          load();
                        },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            if (!widget.reservationsOnly)
              SizedBox(
                height: 64 + MediaQuery.textScalerOf(context).scale(32),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  children: [for (var i = 0; i < 7; i++) dayChip(i, today)],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: SectionHeader(
                  widget.reservationsOnly
                      ? 'Réservations de la semaine sélectionnée'
                      : '${dayLabel(day)} · ${iso(week.add(Duration(days: day)))}',
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: load,
                child: list.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 40),
                          Empty(
                            Icons.event_busy_rounded,
                            widget.reservationsOnly && reservationFilter == 2
                                ? 'Les réservations annulées ne sont pas conservées. Vous pouvez réserver de nouveau depuis le planning.'
                                : query.isNotEmpty || onlyMine
                                ? 'Aucun cours ne correspond à vos filtres.'
                                : 'Aucun cours ce jour',
                            cta:
                                !widget.reservationsOnly &&
                                    (query.isNotEmpty || onlyMine)
                                ? 'Effacer les filtres'
                                : null,
                            onTap: () => setState(() {
                              search = '';
                              searchController.clear();
                              onlyMine = widget.reservationsOnly;
                            }),
                          ),
                        ],
                      )
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: list.length,
                        itemBuilder: (_, i) => tile(list[i]),
                      ),
              ),
            ),
          ],
        ),
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
  final Set<int> saving = {};
  bool get isToday =>
      widget.cls['session_date'] != null &&
      !DateTime.parse(
        '${widget.cls['session_date']} ${widget.cls['time']}:00',
      ).isAfter(DateTime.now());

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      list = await PlanningService.participants(
        widget.cls['id'] as int,
        date: widget.cls['session_date'] as String?,
      );
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> mark(Json p, String status) async {
    final id = p['id'] as int;
    if (saving.contains(id)) return;
    setState(() => saving.add(id));
    try {
      if (await attempt(
        context,
        () => PlanningService.markPresent(
          widget.cls['id'] as int,
          id,
          date: widget.cls['session_date'] as String?,
          status: status,
        ),
      )) {
        await load();
      }
    } finally {
      if (mounted) setState(() => saving.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final present = list.where((p) => isTrue(p['present'])).length;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.cls['title']} · ${widget.cls['time']}'),
      ),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isToday ? cs.primaryContainer : cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    isToday
                        ? Icons.how_to_reg_rounded
                        : Icons.info_outline_rounded,
                    color: isToday
                        ? cs.onPrimaryContainer
                        : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isToday
                          ? '$present / ${list.length} présences confirmées'
                          : 'La présence pourra être vérifiée lorsque le cours aura commencé.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isToday
                            ? cs.onPrimaryContainer
                            : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              const Empty(
                Icons.people_outline_rounded,
                'Aucune réservation pour ce cours',
              ),
            for (final p in list)
              Card(
                child: ListTile(
                  leading: InitialAvatar('${p['name']}'),
                  title: Text('${p['name']}'),
                  subtitle: Text(
                    '${widget.cls['session_date']} · ${p['phone'] ?? 'Pas de téléphone'}',
                  ),
                  trailing: saving.contains(p['id'])
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : PopupMenuButton<String>(
                          enabled: isToday,
                          tooltip: 'Modifier la présence',
                          onSelected: (status) => mark(p, status),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'present',
                              child: Text('Présent'),
                            ),
                            PopupMenuItem(
                              value: 'absent',
                              child: Text('Absent'),
                            ),
                            PopupMenuItem(
                              value: 'pending',
                              child: Text('À vérifier'),
                            ),
                          ],
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              p['attendance_status'] == 'present' ||
                                      isTrue(p['present'])
                                  ? 'Présent ▾'
                                  : p['attendance_status'] == 'absent'
                                  ? 'Absent ▾'
                                  : 'À vérifier ▾',
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
