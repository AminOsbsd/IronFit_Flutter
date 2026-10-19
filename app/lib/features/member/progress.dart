import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/theme/spacing.dart';
import '../../core/utils/values.dart';
import '../../core/widgets/async_view.dart';
import '../../core/widgets/charts.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/form_dialog.dart';
import '../../core/widgets/kpi.dart';

/// Résumé des mesures (ordre chronologique) : poids, évolution, dernière masse grasse.
class ProgressSummary {
  final List<double> weights;
  final Object? lastBodyFat;

  ProgressSummary(List<Json> chronological)
    : weights = [
        for (final m in chronological)
          if (m['weight'] != null) toDouble(m['weight']),
      ],
      lastBodyFat = chronological.lastWhere((m) => m['body_fat'] != null, orElse: () => const {})['body_fat'];

  /// Différence entre la dernière et la première pesée (0 s'il y en a moins de deux).
  double get change => weights.length >= 2 ? weights.last - weights.first : 0;
}

/// Courbe de poids et historique des mesures d'un membre (le sien, ou celui d'un client pour son coach).
class ProgressView extends StatefulWidget {
  final int memberId;
  const ProgressView({super.key, required this.memberId});

  @override
  State<ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<ProgressView> with AsyncLoadMixin<ProgressView, List<Json>> {
  @override
  Future<List<Json>> fetch() async =>
      (await Api.list(Api.withQuery('measures', {'member_id': widget.memberId})))
        ..sort((a, b) => '${a['measured_on']}'.compareTo('${b['measured_on']}'));

  Future<void> add() async {
    final r = await formDialog(context, 'Nouvelle mesure', const [
      DField('measured_on', 'Date', type: DType.date, required: true),
      DField('weight', 'Poids (kg)', type: DType.decimal, min: 20, max: 400),
      DField('body_fat', 'Masse grasse (%)', type: DType.decimal, max: 100),
      DField('note', 'Note'),
    ], submit: (v) => Api.call('POST', 'measures', {...v, 'member_id': widget.memberId}));
    if (r != null) await reload();
  }

  List<Widget> content(List<Json> ms) {
    final s = ProgressSummary(ms);
    final w = s.weights, delta = s.change;
    return [
      KpiGrid(
        columns: 3,
        children: [
          KpiCard(icon: Icons.monitor_weight, label: 'Poids actuel', value: w.isEmpty ? '—' : '${w.last} kg'),
          KpiCard(
            icon: delta <= 0 ? Icons.trending_down : Icons.trending_up,
            label: 'Évolution',
            value: '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg',
          ),
          KpiCard(
            icon: Icons.percent,
            label: 'Masse grasse',
            value: s.lastBodyFat == null ? '—' : '${s.lastBodyFat} %',
          ),
        ],
      ),
      if (w.length >= 2)
        Card(
          child: Padding(
            padding: Gaps.page,
            child: LineChart(
              values: w,
              semanticsLabel: 'Évolution du poids sur ${w.length} mesures : de ${w.first} à ${w.last} kilos.',
            ),
          ),
        ),
      const SectionTitle('Historique'),
      for (final m in ms.reversed)
        Card(
          child: ListTile(
            title: Text('${m['weight'] ?? '—'} kg · ${m['body_fat'] ?? '—'} % MG'),
            subtitle: Text('${m['measured_on'] ?? '—'} · ${m['note'] ?? ''}'),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) => AsyncStateView(
    loading: loading,
    error: error,
    data: data,
    onRetry: reload,
    builder: (context, ms) => RefreshIndicator(
      onRefresh: reload,
      child: ListView(
        padding: Gaps.page,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: add,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une mesure'),
            ),
          ),
          if (ms.isEmpty)
            const EmptyState(icon: Icons.show_chart, text: 'Aucune mesure pour le moment.')
          else
            ...content(ms),
        ],
      ),
    ),
  );
}

class ProgressPage extends StatelessWidget {
  final int memberId;
  final String title;
  const ProgressPage({super.key, required this.memberId, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ProgressView(memberId: memberId),
  );
}
