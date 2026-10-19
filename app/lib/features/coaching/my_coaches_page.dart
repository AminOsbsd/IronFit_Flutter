import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/kpi.dart';
import 'coaches_tab.dart';

/// Mes coachs : suivis en cours et demandes, avec possibilité d'y mettre fin.
class MyCoachesPage extends StatefulWidget {
  const MyCoachesPage({super.key});

  @override
  State<MyCoachesPage> createState() => _MyCoachesPageState();
}

class _MyCoachesPageState extends State<MyCoachesPage> with AsyncLoadMixin<MyCoachesPage, List<Json>> {
  @override
  Future<List<Json>> fetch() => Api.list('coaching/mine');

  Future<void> end(Json l) async {
    final pending = l['status'] == 'pending';
    final ok = await confirm(
      context,
      pending ? 'Annuler la demande ?' : 'Arrêter le suivi avec ${l['coach_name']} ?',
      body: pending ? null : 'Le coach n\'aura plus accès à vos données.',
      ok: pending ? 'Annuler la demande' : 'Arrêter',
    );
    if (ok && mounted && await attempt(context, () => Api.call('POST', 'coaching/${l['id']}/end'))) await reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mes coachs'),
      actions: [RefreshButton(onPressed: reload)],
    ),
    body: AsyncStateView(
      loading: loading,
      error: error,
      data: data,
      onRetry: reload,
      builder: (context, links) {
        final current = links.where((l) => l['status'] == 'active' || l['status'] == 'pending').toList();
        final past = links.where((l) => !current.contains(l)).toList();
        final success = AppColors.of(context).success;
        return RefreshIndicator(
          onRefresh: reload,
          child: ListView(
            padding: Gaps.page,
            children: [
              if (current.isEmpty)
                const Card(
                  child: EmptyState(
                    icon: Icons.sports,
                    text: 'Aucun coach pour le moment.\nTrouvez-en un dans Explorer → Coachs.',
                  ),
                ),
              for (final l in current)
                Card(
                  child: ListTile(
                    leading: Icon(
                      l['status'] == 'active' ? Icons.verified : Icons.hourglass_top,
                      color: l['status'] == 'active' ? success : null,
                    ),
                    title: Text('${l['coach_name']}'),
                    subtitle: Text('${l['coach_specialty'] ?? 'Coach'} · ${coachingStatusLabels[l['status']]}'),
                    trailing: TextButton(
                      onPressed: () => end(l),
                      child: Text(l['status'] == 'pending' ? 'Annuler' : 'Arrêter'),
                    ),
                  ),
                ),
              if (past.isNotEmpty) const SectionTitle('Historique'),
              for (final l in past)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: Text('${l['coach_name']}'),
                    subtitle: Text('${coachingStatusLabels[l['status']]} · ${datePart(l['updated'])}'),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}
