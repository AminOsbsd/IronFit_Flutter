import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';

/// Membres inscrits à un cours + pointage de présence (le jour même).
class ParticipantsPage extends StatefulWidget {
  final Json cls;
  const ParticipantsPage(this.cls, {super.key});

  @override
  State<ParticipantsPage> createState() => _ParticipantsPageState();
}

class _ParticipantsPageState extends State<ParticipantsPage> with AsyncLoadMixin<ParticipantsPage, List<Json>> {
  int get day => toInt(widget.cls['day']);
  bool get isToday => day == todayIndex();

  @override
  Future<List<Json>> fetch() => Api.list('classes/${widget.cls['id']}/participants');

  Future<void> mark(Json p) async {
    final ok = await attempt(
      context,
      () => Api.call('POST', 'classes/${widget.cls['id']}/present', {'member_id': p['id']}),
    );
    if (ok) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final success = AppColors.of(context).success;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.cls['title']} · ${widget.cls['time']}'),
        actions: [RefreshButton(onPressed: reload)],
      ),
      body: AsyncStateView(
        loading: loading,
        error: error,
        data: data,
        onRetry: reload,
        builder: (context, list) {
          final present = list.where((p) => asBool(p['present'])).length;
          return Column(
            children: [
              ColoredBox(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: Gaps.page,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      isToday
                          ? '$present / ${list.length} présents aujourd\'hui'
                          : 'Le pointage est possible uniquement le jour de la séance (${dayLabel(day)}).',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: list.isEmpty
                    ? const EmptyState(icon: Icons.people_outline, text: 'Aucune réservation pour cette séance')
                    : ListView(
                        padding: Gaps.page,
                        children: [
                          for (final p in list)
                            Card(
                              child: ListTile(
                                leading: InitialAvatar(p['name']),
                                title: Text('${p['name'] ?? ''}'),
                                subtitle: Text('${p['phone'] ?? 'Pas de téléphone'}'),
                                trailing: asBool(p['present'])
                                    ? Chip(
                                        avatar: Icon(Icons.check_circle, color: success),
                                        label: const Text('Présent'),
                                      )
                                    : FilledButton.tonal(
                                        onPressed: isToday ? () => mark(p) : null,
                                        child: const Text('Pointer'),
                                      ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
