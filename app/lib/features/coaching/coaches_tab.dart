import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';

/// Libellé d'une relation de coaching, vue côté membre.
const coachingStatusLabels = {
  'pending': 'Demande envoyée',
  'active': 'Votre coach',
  'declined': 'Demande refusée',
  'ended': 'Suivi terminé',
};

typedef CoachesData = ({List<Json> coaches, List<Json> links});

/// Annuaire des coachs (vue membre) : spécialité, demande de suivi.
class CoachesTab extends StatefulWidget {
  const CoachesTab({super.key});

  @override
  State<CoachesTab> createState() => _CoachesTabState();
}

class _CoachesTabState extends State<CoachesTab> with AsyncLoadMixin<CoachesTab, CoachesData> {
  @override
  Future<CoachesData> fetch() async {
    final (coaches, links) = await (Api.list('coaches'), Api.list('coaching/mine')).wait;
    return (coaches: coaches, links: links);
  }

  Future<void> request(Json c) async {
    final ok = await confirm(
      context,
      'Demander un suivi à ${c['name']} ?',
      body: 'Le coach pourra voir vos mesures et vous préparer des programmes une fois la demande acceptée.',
      ok: 'Envoyer',
    );
    if (!ok || !mounted) return;
    final sent = await attempt(
      context,
      () => Api.call('POST', 'coaching/request', {'coach_id': c['id']}),
      success: 'Demande envoyée ✓',
    );
    if (sent) await reload();
  }

  Widget tile(Json c, List<Json> links) {
    final st = links.where((l) => l['coach_id'] == c['id']).firstOrNull?['status'] as String?;
    final busy = st == 'pending' || st == 'active';
    return Card(
      child: ListTile(
        leading: InitialAvatar(c['name']),
        title: Text('${c['name'] ?? ''}'),
        subtitle: Text(
          '${c['specialty'] ?? 'Coach'} · ${c['classes'] ?? 0} cours/semaine'
          '${st == null ? '' : '\n${coachingStatusLabels[st] ?? st}'}',
        ),
        isThreeLine: st != null,
        trailing: busy
            ? Icon(
                st == 'active' ? Icons.verified : Icons.hourglass_top,
                color: st == 'active' ? AppColors.of(context).success : null,
                semanticLabel: coachingStatusLabels[st],
              )
            : FilledButton.tonal(onPressed: () => request(c), child: const Text('Demander')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AsyncStateView(
    loading: loading,
    error: error,
    data: data,
    onRetry: reload,
    builder: (context, d) {
      final others = d.coaches.where((c) => c['id'] != Api.myId).toList();
      if (others.isEmpty) return const EmptyState(icon: Icons.sports, text: 'Aucun coach disponible pour le moment');
      return RefreshIndicator(
        onRefresh: reload,
        child: ListView(padding: Gaps.page, children: [for (final c in others) tile(c, d.links)]),
      );
    },
  );
}
