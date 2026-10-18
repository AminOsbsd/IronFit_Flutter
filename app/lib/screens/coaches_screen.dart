import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/common_widgets.dart';

const _status = {'pending': 'Demande envoyée', 'active': 'Votre coach', 'declined': 'Demande refusée', 'ended': 'Suivi terminé'};

/// Annuaire des coachs (vue membre) : spécialité, demande de suivi.
class CoachesTab extends StatefulWidget {
  const CoachesTab({super.key});
  @override
  State<CoachesTab> createState() => _CoachesTabState();
}

class _CoachesTabState extends State<CoachesTab> {
  List<Map<String, dynamic>> coaches = [], links = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      coaches = await Api.list('coaches');
      links = await Api.list('coaching/mine');
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> request(Map<String, dynamic> c) async {
    if (!await confirm(context, 'Demander un suivi à ${c['name']} ?', body: 'Le coach pourra voir vos mesures et vous préparer des programmes une fois la demande acceptée.', ok: 'Envoyer')) return;
    if (mounted && await attempt(context, () => Api.call('POST', 'coaching/request', {'coach_id': c['id']}), success: 'Demande envoyée ✓')) load();
  }

  @override
  Widget build(BuildContext context) => AsyncBody(
        loading: loading,
        error: error,
        onRetry: load,
        builder: () {
          final others = coaches.where((c) => c['id'] != Api.myId).toList();
          if (others.isEmpty) return const Empty(Icons.sports, 'Aucun coach disponible pour le moment');
          return RefreshIndicator(
            onRefresh: load,
            child: ListView(padding: const EdgeInsets.all(12), children: [
              for (final c in others)
                Builder(builder: (_) {
                  final l = links.where((l) => l['coach_id'] == c['id']).firstOrNull;
                  final st = l?['status'] as String?;
                  final busy = st == 'pending' || st == 'active';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text('${c['name']}'[0].toUpperCase())),
                      title: Text('${c['name']}'),
                      subtitle: Text('${c['specialty'] ?? 'Coach'} · ${c['classes']} cours/semaine${st == null ? '' : '\n${_status[st]}'}'),
                      isThreeLine: st != null,
                      trailing: busy ? Icon(st == 'active' ? Icons.verified : Icons.hourglass_top, color: st == 'active' ? Colors.green : null) : FilledButton.tonal(onPressed: () => request(c), child: const Text('Demander')),
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
  List<Map<String, dynamic>> links = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      links = await Api.list('coaching/mine');
      error = null;
    } catch (e) {
      error = '$e';
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> end(Map<String, dynamic> l) async {
    final pending = l['status'] == 'pending';
    if (!await confirm(context, pending ? 'Annuler la demande ?' : 'Arrêter le suivi avec ${l['coach_name']} ?', body: pending ? null : 'Le coach n\'aura plus accès à vos données.', ok: pending ? 'Annuler la demande' : 'Arrêter')) return;
    if (mounted && await attempt(context, () => Api.call('POST', 'coaching/${l['id']}/end'))) load();
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
              child: ListView(padding: const EdgeInsets.all(12), children: [
                if (current.isEmpty) const Card(child: Empty(Icons.sports, 'Aucun coach pour le moment.\nTrouvez-en un dans Explorer → Coachs.')),
                for (final l in current)
                  Card(
                    child: ListTile(
                      leading: Icon(l['status'] == 'active' ? Icons.verified : Icons.hourglass_top, color: l['status'] == 'active' ? Colors.green : null),
                      title: Text('${l['coach_name']}'),
                      subtitle: Text('${l['coach_specialty'] ?? 'Coach'} · ${_status[l['status']]}'),
                      trailing: TextButton(onPressed: () => end(l), child: Text(l['status'] == 'pending' ? 'Annuler' : 'Arrêter')),
                    ),
                  ),
                if (past.isNotEmpty) sectionTitle(context, 'Historique'),
                for (final l in past) Card(child: ListTile(leading: const Icon(Icons.history), title: Text('${l['coach_name']}'), subtitle: Text('${_status[l['status']]} · ${'${l['updated']}'.split(' ').first}'))),
              ]),
            );
          },
        ),
      );
}
