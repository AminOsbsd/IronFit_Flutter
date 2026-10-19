import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/kpi.dart';
import '../planning/participants_page.dart';
import '../shell/notification_bell.dart';

// Espace coach. Le serveur limite toutes ces données aux clients dont la relation de coaching est active.

typedef CoachDashboard = ({Json stats, List<Json> pending, List<Json> today});

/// Accueil coach : indicateurs, demandes de suivi, cours du jour, alertes.
class CoachHome extends StatefulWidget {
  const CoachHome({super.key});

  @override
  State<CoachHome> createState() => _CoachHomeState();
}

class _CoachHomeState extends State<CoachHome> with AsyncLoadMixin<CoachHome, CoachDashboard> {
  @override
  Future<CoachDashboard> fetch() async {
    await Api.refreshMe();
    final (stats, links, classes) = await (Api.get('stats'), Api.list('coaching/clients'), Api.list('classes')).wait;
    unawaited(Api.refreshUnread());
    final dow = todayIndex();
    return (
      stats: stats,
      pending: links.where((l) => l['status'] == 'pending').toList(),
      today: classes.where((c) => c['day'] == dow && c['coach_id'] == Api.myId).toList(),
    );
  }

  Future<void> answer(Json l, bool accept) async {
    final ok = await attempt(
      context,
      () => Api.call('POST', 'coaching/${l['id']}/${accept ? 'accept' : 'decline'}'),
      success: accept ? '${l['client_name']} fait partie de vos clients ✓' : null,
    );
    if (ok) await reload();
  }

  Future<void> openParticipants(Json c) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => ParticipantsPage(c)));
    await reload();
  }

  List<Widget> content(CoachDashboard d) {
    final colors = AppColors.of(context);
    final st = d.stats;
    final expiring = jsonList(st, 'expiring'), maint = jsonList(st, 'maintenance'), fill = jsonList(st, 'fill');
    return [
      KpiGrid(
        children: [
          KpiCard(icon: Icons.groups, label: 'Clients suivis', value: '${st['clients'] ?? 0}'),
          KpiCard(icon: Icons.list_alt, label: 'Programmes actifs', value: '${st['programs'] ?? 0}'),
          KpiCard(
            icon: Icons.local_fire_department,
            label: 'Séances clients (7 j)',
            value: '${st['workouts7d'] ?? 0}',
            color: colors.success,
          ),
          KpiCard(
            icon: Icons.rate_review,
            label: 'Séances à commenter',
            value: '${st['toReview'] ?? 0}',
            color: colors.warning,
          ),
        ],
      ),
      if (d.pending.isNotEmpty) ...[
        const SectionTitle('Demandes de suivi'),
        for (final l in d.pending)
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_add),
              title: Text('${l['client_name']}'),
              subtitle: Text('@${l['client_login']} · demandé le ${datePart(l['created'])}'),
              trailing: Wrap(
                spacing: Gaps.xs,
                children: [
                  TextButton(onPressed: () => answer(l, false), child: const Text('Refuser')),
                  FilledButton(onPressed: () => answer(l, true), child: const Text('Accepter')),
                ],
              ),
            ),
          ),
      ],
      const SectionTitle('Mes cours aujourd\'hui'),
      if (d.today.isEmpty)
        const Card(
          child: EmptyState(icon: Icons.event_busy, text: 'Aucun cours à animer aujourd\'hui'),
        ),
      for (final c in d.today)
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule),
            title: Text('${c['time']} · ${c['title']}'),
            subtitle: Text('${toInt(c['taken'])}/${toInt(c['spots'])} inscrits'),
            trailing: OutlinedButton(onPressed: () => openParticipants(c), child: const Text('Pointer')),
          ),
        ),
      if (expiring.isNotEmpty) ...[
        const SectionTitle('Abonnements de mes clients qui expirent'),
        for (final a in expiring)
          Card(
            child: ListTile(
              leading: ExcludeSemantics(child: Icon(Icons.timer, color: colors.warning)),
              title: Text('${a['name']}'),
              subtitle: Text('Expire le ${a['sub_end']}'),
            ),
          ),
      ],
      if (maint.isNotEmpty) ...[
        const SectionTitle('Matériel à vérifier'),
        Card(
          child: ListTile(
            leading: ExcludeSemantics(child: Icon(Icons.build, color: colors.warning)),
            title: Text(maint.map((e) => e['name']).join(', ')),
          ),
        ),
      ],
      if (fill.isNotEmpty) ...[
        const SectionTitle('Remplissage de mes cours'),
        Card(
          child: Padding(
            padding: Gaps.page,
            child: Column(
              children: [
                for (final c in fill)
                  FillRow(
                    label: '${c['title']} · ${dayShort[toInt(c['day']) % 7]}',
                    taken: toInt(c['taken']),
                    spots: toInt(c['spots']),
                  ),
              ],
            ),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Coach ${firstName(Api.me?['name'])}'),
        actions: [
          const NotificationBell(),
          RefreshButton(onPressed: reload),
        ],
      ),
      body: AsyncStateView(
        loading: loading,
        error: error,
        data: data,
        onRetry: reload,
        builder: (context, d) => RefreshIndicator(
          onRefresh: reload,
          child: ListView(padding: Gaps.page, children: content(d)),
        ),
      ),
    );
  }
}
