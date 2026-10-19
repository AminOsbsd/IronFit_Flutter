import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../crud/crud_page.dart';
import '../crud/module_catalogue.dart';
import 'booking.dart';
import 'participants_page.dart';

/// Planning hebdomadaire : puces de jours + cours du jour choisi.
/// [manage] = false : réserver / annuler (membre, ou coach dans son espace perso).
/// [manage] = true : participants et pointage (admin : tous les cours ; coach : ses cours).
class PlanningPage extends StatefulWidget {
  final bool manage;
  const PlanningPage({super.key, this.manage = false});

  @override
  State<PlanningPage> createState() => _PlanningPageState();
}

class _PlanningPageState extends State<PlanningPage> with AsyncLoadMixin<PlanningPage, List<Json>> {
  int day = todayIndex();

  bool get manage => widget.manage;
  bool runsIt(Json c) => Api.isAdmin || c['coach_id'] == Api.myId;

  @override
  Future<List<Json>> fetch() => Api.list('classes');

  Future<void> openParticipants(Json c) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ParticipantsPage(c)));
    await reload();
  }

  Widget tile(Json c) {
    final slot = ClassSlot(c);
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: Gaps.card,
        child: Row(
          children: [
            Text('${c['time']}', style: t.titleLarge),
            Gaps.w16,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${c['title']}', style: t.titleMedium),
                  Text('Coach : ${c['coach_name'] ?? '—'}', style: t.bodySmall),
                  Gaps.h8,
                  LinearProgressIndicator(
                    value: slot.ratio,
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                    semanticsLabel: 'Remplissage',
                  ),
                  Gaps.h4,
                  Text('${slot.taken.toInt()}/${slot.spots.toInt()} places', style: t.bodySmall),
                ],
              ),
            ),
            Gaps.w12,
            if (manage)
              runsIt(c)
                  ? OutlinedButton(onPressed: () => openParticipants(c), child: const Text('Participants'))
                  : const SizedBox.shrink()
            else
              BookButton(cls: c, onChanged: reload),
          ],
        ),
      ),
    );
  }

  Widget dayChips(List<Json> classes) {
    final today = todayIndex();
    // La hauteur suit la taille de texte choisie par l'utilisateur (accessibilité).
    final height = MediaQuery.textScalerOf(context).scale(36) + 2 * Gaps.sm;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: Gaps.xs),
        itemCount: 7,
        separatorBuilder: (_, _) => Gaps.w8,
        itemBuilder: (_, i) {
          final n = classes.where((c) => c['day'] == i).length;
          return Semantics(
            label: '${dayNames[i]}${i == today ? ', aujourd\'hui' : ''}, ${plural(n, 'cours', 'cours')}',
            selected: day == i,
            button: true,
            excludeSemantics: true,
            child: ChoiceChip(
              label: Text('${dayShort[i]}${i == today ? ' •' : ''}${n > 0 ? '  $n' : ''}'),
              selected: day == i,
              onSelected: (_) => setState(() => day = i),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planning'),
        actions: [
          if (manage)
            IconButton(
              tooltip: 'Gérer les séances',
              icon: const Icon(Icons.edit_calendar),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => CrudPage(moduleById('classes'))));
                await reload();
              },
            ),
          RefreshButton(onPressed: reload),
        ],
      ),
      body: AsyncStateView(
        loading: loading,
        error: error,
        data: data,
        onRetry: reload,
        builder: (context, classes) {
          final list = classes.where((c) => c['day'] == day).toList();
          return Column(
            children: [
              dayChips(classes),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: reload,
                  child: list.isEmpty
                      ? const ScrollableEmptyState(
                          child: EmptyState(icon: Icons.event_busy, text: 'Aucune séance ce jour'),
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(Gaps.md, 0, Gaps.md, Gaps.lg),
                          itemCount: list.length,
                          itemBuilder: (_, i) => tile(list[i]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
