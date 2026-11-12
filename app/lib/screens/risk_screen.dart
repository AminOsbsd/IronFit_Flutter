import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../services/risk_service.dart';
import '../widgets/common_widgets.dart';

// Membres à risque d'abandon (coach : ses clients ; admin : tous les membres).
// Le score (0-100) et ses explications viennent du serveur ; l'écran ne fait qu'afficher et relancer.

Color riskColor(String? level) => switch (level) {
      'high' => AppColors.danger,
      'medium' => AppColors.warning,
      _ => AppColors.success,
    };

String riskLabel(String? level) => switch (level) {
      'high' => 'Risque élevé',
      'medium' => 'Risque moyen',
      _ => 'Risque faible',
    };

class RiskPage extends StatefulWidget {
  const RiskPage({super.key});
  @override
  State<RiskPage> createState() => _RiskPageState();
}

class _RiskPageState extends State<RiskPage> {
  bool loading = true, all = false;
  String? error;
  List<Map<String, dynamic>> items = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      items = await RiskService.atRisk(all: all);
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> remind(Map<String, dynamic> m) async {
    final ok = await confirm(context, 'Relancer ${m['name']} ?',
        body: 'Une notification sera envoyée au membre (et un e-mail si le serveur d\'e-mail est configuré).', ok: 'Envoyer');
    if (!ok || !mounted) return;
    Map<String, dynamic>? res;
    if (await attempt(context, () async => res = await RiskService.remind(m['id'] as int)) && mounted) {
      final sent = res?['email_sent'] == true;
      snack(context, sent
          ? 'Relance envoyée à ${m['name']} · e-mail envoyé ✓'
          : 'Notification envoyée, mais e-mail NON envoyé : ${res?['email_info'] ?? 'raison inconnue'}');
      load();
    }
  }

  /// Admin : lance l'analyse automatique sans attendre l'heure programmée.
  Future<void> runNow() async {
    var sent = 0;
    if (await attempt(context, () async => sent = await RiskService.runNow()) && mounted) {
      snack(context, sent == 0 ? 'Aucune nouvelle relance à envoyer' : '$sent relance${sent > 1 ? 's' : ''} automatique${sent > 1 ? 's' : ''} envoyée${sent > 1 ? 's' : ''} ✓');
      load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Membres à risque'),
        actions: [
          if (Api.isAdmin) IconButton(tooltip: 'Lancer l\'analyse maintenant', onPressed: runNow, icon: const Icon(Icons.play_circle_outline_rounded)),
          IconButton(tooltip: 'Actualiser', onPressed: load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () => RefreshIndicator(
          onRefresh: load,
          child: ListView(padding: const EdgeInsets.all(12), physics: const AlwaysScrollableScrollPhysics(), children: [
            Card(
              child: SwitchListTile(
                title: const Text('Afficher aussi les risques faibles'),
                subtitle: const Text('Score = inactivité + régularité + abonnement'),
                value: all,
                onChanged: (v) {
                  setState(() {
                    all = v;
                    loading = true;
                  });
                  load();
                },
              ),
            ),
            if (items.isEmpty) const Card(child: Empty(Icons.verified_rounded, 'Aucun membre à risque pour le moment 🎉')),
            for (final m in items) _RiskCard(m, onRemind: () => remind(m)),
          ]),
        ),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  final Map<String, dynamic> m;
  final VoidCallback onRemind;
  const _RiskCard(this.m, {required this.onRemind});

  @override
  Widget build(BuildContext context) {
    final level = m['level'] as String?;
    final color = riskColor(level);
    final score = (m['score'] as num?)?.toInt() ?? 0;
    final reasons = ((m['reasons'] ?? []) as List).map((e) => '$e').toList();
    final last = m['last_reminder'];
    final small = Theme.of(context).textTheme.bodySmall;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Stack(alignment: Alignment.center, children: [
              SizedBox(width: 52, height: 52, child: CircularProgressIndicator(value: score / 100, strokeWidth: 5, color: color, backgroundColor: color.withValues(alpha: 0.15))),
              Text('$score', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${m['name']}', style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis),
                Text('@${m['login']}', style: small),
              ]),
            ),
            StatusPill(riskLabel(level), color: color),
          ]),
          const SizedBox(height: 10),
          if (reasons.isEmpty) Text('Aucun signal d\'alerte', style: small),
          for (final r in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.chevron_right_rounded, size: 18, color: color),
                Expanded(child: Text(r)),
              ]),
            ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(last == null ? 'Jamais relancé' : 'Dernière relance : ${dateOnly(last)}', style: small)),
            FilledButton.icon(onPressed: onRemind, icon: const Icon(Icons.notifications_active_rounded, size: 18), label: const Text('Relancer')),
          ]),
        ]),
      ),
    );
  }
}
