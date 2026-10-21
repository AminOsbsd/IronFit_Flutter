import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../services/coach_service.dart';
import '../services/user_service.dart';
import '../widgets/common_widgets.dart';

const _status = {'pending': 'Demande envoyée', 'active': 'Votre coach', 'declined': 'Demande refusée', 'ended': 'Suivi terminé'};

/// Annuaire des coachs (vue membre) : spécialité, demande de suivi.
class CoachesTab extends StatefulWidget {
  const CoachesTab({super.key});
  @override
  State<CoachesTab> createState() => _CoachesTabState();
}

class _CoachesTabState extends State<CoachesTab> {
  List<Json> coaches = [], links = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      coaches = await UserService.coaches();
      links = await CoachService.myCoaches();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> request(Json c) async {
    if (!await confirm(context, 'Demander un suivi à ${c['name']} ?', body: 'Le coach pourra voir vos mesures et vous préparer des programmes une fois la demande acceptée.', ok: 'Envoyer')) return;
    if (mounted && await attempt(context, () => CoachService.requestCoach(c['id'] as int), success: 'Demande envoyée ✓')) load();
  }

  @override
  Widget build(BuildContext context) => AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () {
          final others = coaches.where((c) => c['id'] != Api.myId).toList();
          if (others.isEmpty) return const Empty(Icons.sports_rounded, 'Aucun coach disponible pour le moment');
          return RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(16), children: [
              for (final c in others)
                Builder(builder: (_) {
                  final l = links.where((l) => l['coach_id'] == c['id']).firstOrNull;
                  final st = l?['status'] as String?;
                  final busy = st == 'pending' || st == 'active';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(children: [
                        InitialAvatar('${c['name']}', radius: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${c['name']}', style: Theme.of(context).textTheme.titleMedium),
                            Text('${c['specialty'] ?? 'Coach'} · ${c['classes']} cours/semaine · ${c['clients']} suivi(s)', style: Theme.of(context).textTheme.bodySmall),
                            if (st != null) Padding(padding: const EdgeInsets.only(top: 6), child: StatusPill(_status[st]!, color: st == 'active' ? AppColors.success : (st == 'pending' ? AppColors.info : AppColors.warning))),
                          ]),
                        ),
                        if (!busy) FilledButton(onPressed: () => request(c), child: const Text('Demander')),
                      ]),
                    ),
                  );
                }),
            ]),
          );
        },
      );
}

/// Mes coachs : suivis en cours et demandes, avec possibilité d'y mettre fin.
class MyCoachesPage extends StatefulWidget {
  const MyCoachesPage({super.key});
  @override
  State<MyCoachesPage> createState() => _MyCoachesPageState();
}

class _MyCoachesPageState extends State<MyCoachesPage> {
  List<Json> links = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      links = await CoachService.myCoaches();
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> end(Json l) async {
    final pending = l['status'] == 'pending';
    if (!await confirm(context, pending ? 'Annuler la demande ?' : 'Arrêter le suivi avec ${l['coach_name']} ?', body: pending ? null : 'Le coach n\'aura plus accès à vos données.', ok: pending ? 'Annuler la demande' : 'Arrêter', danger: !pending)) return;
    if (mounted && await attempt(context, () => CoachService.endLink(l['id'] as int))) load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Mes coachs')),
        body: AsyncBody(
          loading: loading,
          error: error,
          onRetry: load,
          builder: () {
            final current = links.where((l) => l['status'] == 'active' || l['status'] == 'pending').toList();
            final past = links.where((l) => !current.contains(l)).toList();
            return RefreshIndicator(
              onRefresh: load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
                if (current.isEmpty) const Card(child: Empty(Icons.sports_rounded, 'Aucun coach pour le moment.\nTrouvez-en un dans Explorer → Coachs.')),
                for (final l in current)
                  Card(
                    child: ListTile(
                      leading: InitialAvatar('${l['coach_name']}'),
                      title: Text('${l['coach_name']}'),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(children: [
                          Flexible(child: Text('${l['coach_specialty'] ?? 'Coach'} · ', overflow: TextOverflow.ellipsis)),
                          StatusPill(_status[l['status']]!, color: l['status'] == 'active' ? AppColors.success : AppColors.info),
                        ]),
                      ),
                      trailing: TextButton(onPressed: () => end(l), child: Text(l['status'] == 'pending' ? 'Annuler' : 'Arrêter')),
                    ),
                  ),
                if (past.isNotEmpty) const SectionHeader('Historique'),
                for (final l in past)
                  Card(child: ListTile(leading: const IconBadge(Icons.history_rounded), title: Text('${l['coach_name']}'), subtitle: Text('${_status[l['status']]} · ${dateOnly(l['updated'])}'))),
              ]),
            );
          },
        ),
      );
}
