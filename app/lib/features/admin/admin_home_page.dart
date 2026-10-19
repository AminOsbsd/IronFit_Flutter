import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/api/refs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/kpi.dart';
import '../member/subscription.dart';
import '../planning/participants_page.dart';
import '../shell/notification_bell.dart';
import 'coaching_admin_page.dart';
import 'requests_page.dart';

typedef AdminDashboard = ({Json stats, List<Json> today});

/// Revenu total du mois ISO [month] (`AAAA-MM`) dans la série `revenue` des statistiques.
double revenueFor(List<Json> revenue, String month) =>
    revenue.where((r) => r['m'] == month).fold<double>(0, (s, r) => s + toDouble(r['total']));

/// Tableau de bord administrateur : indicateurs, alertes, revenus, cours du jour, renouvellements, remplissage.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> with AsyncLoadMixin<AdminHome, AdminDashboard> {
  @override
  Future<AdminDashboard> fetch() async {
    final (_, stats, _, classes) = await (Api.refreshMe(), Api.get('stats'), Refs.load(), Api.list('classes')).wait;
    unawaited(Api.refreshUnread());
    final dow = todayIndex();
    return (stats: stats, today: classes.where((c) => c['day'] == dow).toList());
  }

  Future<void> open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
    await reload();
  }

  Future<void> renew(Json a) async {
    final plans = Refs.data['plans'] ?? const <Json>[];
    if (plans.isEmpty) {
      showSnack(context, 'Aucun tarif défini');
      return;
    }
    Object? plan = plans.any((p) => p['id'] == a['plan_id']) ? a['plan_id'] : plans.first['id'];
    var method = payMethods.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text('Renouveler ${a['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Object?>(
                initialValue: plan,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Abonnement'),
                items: [
                  for (final p in plans)
                    DropdownMenuItem<Object?>(value: p['id'], child: Text('${p['name']} — ${p['price']} DT')),
                ],
                onChanged: (x) => set(() => plan = x),
              ),
              Gaps.h12,
              DropdownButtonFormField<String>(
                initialValue: method,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Mode de paiement'),
                items: [for (final e in payMethods) DropdownMenuItem(value: e, child: Text(e))],
                onChanged: (x) => set(() => method = x ?? method),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Renouveler')),
          ],
        ),
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    final done = await attempt(
      context,
      () => Api.call('POST', 'members/${a['id']}/renew', {'plan_id': plan, 'method': method}),
      success: 'Abonnement renouvelé, paiement enregistré ✓',
    );
    if (done) await reload();
  }

  Widget alert(IconData i, String text, Color c, {VoidCallback? onTap}) => Card(
    child: ListTile(
      leading: ExcludeSemantics(child: Icon(i, color: c)),
      title: Text(text),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );

  List<Widget> content(AdminDashboard d) {
    final cs = Theme.of(context).colorScheme;
    final colors = AppColors.of(context);
    final st = d.stats;
    final expiring = jsonList(st, 'expiring'), lapsed = jsonList(st, 'lapsed'), low = jsonList(st, 'lowStock');
    final maint = jsonList(st, 'maintenance'), rev = jsonList(st, 'revenue'), fill = jsonList(st, 'fill');
    final pending = toInt(st['pending']), pendingCoach = toInt(st['pendingCoachings']);
    final monthRev = revenueFor(rev, todayIso().substring(0, 7));
    final alerts = <Widget>[
      if (pending > 0)
        alert(
          Icons.assignment_ind,
          '${plural(pending, 'demande')} d\'abonnement à valider',
          cs.primary,
          onTap: () => open(const RequestsPage()),
        ),
      if (pendingCoach > 0)
        alert(
          Icons.sports,
          '${plural(pendingCoach, 'demande')} de coaching en attente de réponse du coach',
          cs.secondary,
          onTap: () => open(const CoachingAdminPage()),
        ),
      if (expiring.isNotEmpty)
        alert(
          Icons.timer,
          '${plural(expiring.length, 'abonnement')} expire${expiring.length > 1 ? 'nt' : ''} cette semaine',
          colors.warning,
        ),
      if (low.isNotEmpty)
        alert(
          Icons.inventory_2,
          'Stock bas : ${low.map((p) => '${p['name']} (${p['stock']})').join(', ')}',
          colors.danger,
        ),
      if (maint.isNotEmpty)
        alert(Icons.build, 'Matériel à vérifier : ${maint.map((e) => e['name']).join(', ')}', colors.warning),
    ];
    final renewList = [...expiring, ...lapsed];
    final revLabels = [for (final r in rev) monthLabel('${r['m']}')];
    final revValues = [for (final r in rev) toDouble(r['total'])];
    return [
      KpiGrid(
        children: [
          KpiCard(icon: Icons.groups, label: 'Membres', value: '${st['athletes'] ?? 0}'),
          KpiCard(
            icon: Icons.verified,
            label: 'Abonnements actifs',
            value: '${st['active'] ?? 0}',
            color: colors.success,
          ),
          KpiCard(
            icon: Icons.warning_amber,
            label: 'Membres sans abonnement',
            value: '${st['expired'] ?? 0}',
            color: colors.warning,
          ),
          KpiCard(icon: Icons.payments, label: 'Revenus du mois', value: '${monthRev.toStringAsFixed(0)} DT'),
          KpiCard(
            icon: Icons.sports,
            label: 'Coachs · suivis actifs',
            value: '${st['coaches'] ?? 0} · ${st['coachings'] ?? 0}',
          ),
          KpiCard(
            icon: Icons.local_fire_department,
            label: 'Séances enregistrées (7 j)',
            value: '${st['workouts7d'] ?? 0}',
          ),
          KpiCard(icon: Icons.how_to_reg, label: 'Présences aujourd\'hui', value: '${st['checkinsToday'] ?? 0}'),
          KpiCard(
            icon: Icons.block,
            label: 'Comptes désactivés',
            value: '${st['disabled'] ?? 0}',
            color: colors.danger,
          ),
        ],
      ),
      const SectionTitle('À surveiller'),
      if (alerts.isEmpty) alert(Icons.check_circle, 'Tout est en ordre ✅', colors.success) else ...alerts,
      if (rev.isNotEmpty) ...[
        const SectionTitle('Revenus par mois (DT)'),
        Card(
          child: Padding(
            padding: Gaps.page,
            child: BarChart(
              labels: revLabels,
              values: revValues,
              semanticsLabel:
                  'Revenus par mois : ${[for (var i = 0; i < rev.length; i++) '${revLabels[i]} ${revValues[i].toStringAsFixed(0)} dinars'].join(', ')}',
            ),
          ),
        ),
      ],
      SectionTitle('Cours aujourd\'hui (${st['bookings'] ?? 0} réservations au total)'),
      if (d.today.isEmpty)
        const Card(
          child: EmptyState(icon: Icons.event_busy, text: 'Aucun cours aujourd\'hui'),
        ),
      for (final c in d.today)
        Card(
          child: ListTile(
            leading: const Icon(Icons.schedule),
            title: Text('${c['time']} · ${c['title']}'),
            subtitle: Text('${c['coach_name'] ?? '—'} · ${toInt(c['taken'])}/${toInt(c['spots'])} inscrits'),
            trailing: OutlinedButton(onPressed: () => open(ParticipantsPage(c)), child: const Text('Pointer')),
          ),
        ),
      if (renewList.isNotEmpty) ...[
        const SectionTitle('Abonnements à renouveler'),
        for (final a in renewList)
          Card(
            child: ListTile(
              leading: const Icon(Icons.person),
              title: Text('${a['name']}'),
              subtitle: Text('${isPast(a['sub_end']) ? 'Expiré' : 'Expire'} le ${a['sub_end']}'),
              trailing: FilledButton.tonal(onPressed: () => renew(a), child: const Text('Renouveler')),
            ),
          ),
      ],
      if (fill.isNotEmpty) ...[
        const SectionTitle('Remplissage des cours'),
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
        title: Text('Administration · ${firstName(Api.me?['name'])}'),
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
