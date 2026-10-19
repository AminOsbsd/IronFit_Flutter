import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/kpi.dart';
import '../coaching/my_coaches_page.dart';
import '../crud/crud_page.dart';
import '../crud/module_catalogue.dart';
import '../programs/program_list.dart';
import '../programs/workouts.dart';
import 'progress.dart';

/// Mon espace : programmes, séances, progression, coachs, présences, paiements.
class MySpacePage extends StatelessWidget {
  const MySpacePage({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData i, String t, String s, Widget page) => Card(
      child: ListTile(
        leading: Icon(i),
        title: Text(t),
        subtitle: Text(s),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page)),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Mon espace')),
      body: ListView(
        padding: Gaps.page,
        children: [
          item(
            Icons.list_alt,
            'Mes programmes',
            'Programmes personnels et programmes de mon coach',
            const ProgramsPage(),
          ),
          item(
            Icons.local_fire_department,
            'Mes séances',
            'Historique d\'entraînement et commentaires du coach',
            const WorkoutHistoryPage(),
          ),
          item(
            Icons.show_chart,
            'Ma progression',
            'Poids, masse grasse, historique',
            ProgressPage(memberId: Api.myId!, title: 'Ma progression'),
          ),
          item(Icons.sports, 'Mes coachs', 'Suivi en cours et demandes', const MyCoachesPage()),
          item(Icons.how_to_reg, 'Mes présences', 'Mes venues aux cours collectifs', const AttendancePage()),
          item(Icons.receipt_long, 'Mes paiements', 'Historique de mes règlements', CrudPage(moduleById('payments'))),
        ],
      ),
    );
  }
}

/// Mes présences aux cours collectifs.
class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> with AsyncLoadMixin<AttendancePage, List<Json>> {
  @override
  Future<List<Json>> fetch() async =>
      (await Api.list(Api.withQuery('checkins', {'member_id': Api.myId})))
        ..sort((a, b) => '${b['checkin_on']}'.compareTo('${a['checkin_on']}'));

  @override
  Widget build(BuildContext context) {
    final month = todayIso().substring(0, 7);
    final success = AppColors.of(context).success;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes présences'),
        actions: [RefreshButton(onPressed: reload)],
      ),
      body: AsyncStateView(
        loading: loading,
        error: error,
        data: data,
        onRetry: reload,
        builder: (context, list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.how_to_reg,
                text: 'Aucune présence enregistrée.\nVos venues sont pointées par le coach pendant les cours.',
              )
            : ListView(
                padding: Gaps.page,
                children: [
                  KpiGrid(
                    columns: 3,
                    children: [
                      KpiCard(
                        icon: Icons.calendar_month,
                        label: 'Ce mois',
                        value: '${list.where((c) => '${c['checkin_on']}'.startsWith(month)).length}',
                      ),
                      KpiCard(icon: Icons.emoji_events, label: 'Total', value: '${list.length}'),
                      KpiCard(
                        icon: Icons.history,
                        label: 'Dernière venue',
                        value: withoutYear('${list.first['checkin_on'] ?? '—'}'),
                      ),
                    ],
                  ),
                  const SectionTitle('Historique'),
                  for (final c in list)
                    Card(
                      child: ListTile(
                        leading: ExcludeSemantics(child: Icon(Icons.check_circle, color: success)),
                        title: Text('${c['note'] ?? 'Entraînement'}'),
                        subtitle: Text('${c['checkin_on'] ?? '—'}'),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
