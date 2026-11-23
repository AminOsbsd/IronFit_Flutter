import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../services/program_service.dart';
import '../widgets/common_widgets.dart';

class GuidedWorkoutPage extends StatefulWidget {
  final Map<String, dynamic> program;
  const GuidedWorkoutPage({super.key, required this.program});
  @override
  State<GuidedWorkoutPage> createState() => _GuidedWorkoutPageState();
}

class _GuidedWorkoutPageState extends State<GuidedWorkoutPage> {
  final form = GlobalKey<FormState>();
  List<Map<String, dynamic>> rows = [];
  late String requestId;
  late DateTime started;
  DateTime? restEnd;
  Timer? timer;
  bool busy = false;
  String? error;
  int restSeconds = 90;
  Future<void> saves = Future.value();
  String get key => 'guided_${Api.myId}_${widget.program['id']}';
  int get remaining => restEnd == null
      ? 0
      : max(0, restEnd!.difference(DateTime.now()).inSeconds);
  @override
  void initState() {
    super.initState();
    started = DateTime.now();
    requestId = List.generate(
      32,
      (_) => Random.secure().nextInt(16).toRadixString(16),
    ).join();
    for (final e in widget.program['items'] as List? ?? []) {
      final count = ((e['sets'] as num?)?.toInt() ?? 1).clamp(1, 50);
      for (var i = 1; i <= count; i++)
        rows.add({
          'exercise_id': e['id'],
          'name': e['name'],
          'set_number': i,
          'target':
              '${e['reps'] ?? '—'} · ${e['load'] ?? '—'} · repos ${e['rest'] ?? 'libre'}',
          'reps': '',
          'weight': '',
          'done': false,
        });
    }
    try {
      final raw = Api.prefs.getString(key);
      if (raw != null) {
        final d = jsonDecode(raw) as Map;
        rows = (d['rows'] as List)
            .map((x) => Map<String, dynamic>.from(x))
            .toList();
        requestId = d['request'];
        started = DateTime.parse(d['started']);
        restEnd = DateTime.tryParse(d['rest_end'] ?? '');
        restSeconds = d['rest_seconds'] ?? 90;
      }
    } catch (_) {
      error =
          'Le brouillon précédent est illisible. Une nouvelle séance est prête.';
    }
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && restEnd != null) setState(() {});
    });
  }

  Future<void> persist() {
    final value = jsonEncode({
      'rows': rows,
      'request': requestId,
      'started': started.toIso8601String(),
      'rest_end': restEnd?.toIso8601String(),
      'rest_seconds': restSeconds,
    });
    saves = saves
        .then((_) async {
          await Api.prefs.setString(key, value);
        })
        .catchError((Object e) {
          if (mounted)
            setState(
              () => error = 'Brouillon non sauvegardé sur cet appareil.',
            );
        });
    return saves;
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> finish() async {
    if (busy) return;
    final completed = rows.where((r) => r['done'] == true).toList();
    if (completed.isEmpty) {
      setState(() => error = 'Validez au moins une série.');
      return;
    }
    if (!form.currentState!.validate()) return;
    if (!await confirm(
      context,
      'Terminer la séance ?',
      body:
          '${completed.length} série(s) validée(s) seront enregistrées. Les autres ne seront pas comptées.',
      ok: 'Enregistrer',
    ))
      return;
    if (!mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await persist();
      await ProgramService.logWorkout({
        'request_id': requestId,
        'done_on': todayIso(),
        'duration': DateTime.now().difference(started).inMinutes.clamp(1, 600),
        'sets': completed
            .map(
              (r) => {
                'exercise_id': r['exercise_id'],
                'set_number': r['set_number'],
                'reps': int.parse(r['reps']),
                'weight': double.parse(
                  (r['weight'] as String).replaceAll(',', '.'),
                ),
              },
            )
            .toList(),
      }, programId: widget.program['id'] as int);
      await saves;
      await Api.prefs.remove(key);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final completed = rows.where((r) => r['done'] == true).length;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.program['title']}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Form(
            key: form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                HeroCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SÉANCE GUIDÉE',
                        style: TextStyle(color: AppColors.amber),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '$completed / ${rows.length} séries validées',
                        style: Theme.of(
                          context,
                        ).textTheme.titleLarge?.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: rows.isEmpty ? 0 : completed / rows.length,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Saisissez les répétitions et la charge réellement réalisées. 0 kg = sans charge ajoutée. Brouillon conservé sur cet appareil.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          restEnd == null
                              ? 'Repos'
                              : remaining == 0
                              ? 'Repos terminé'
                              : 'Repos · ${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final sec in [30, 60, 90, 120])
                              ChoiceChip(
                                label: Text('$sec s'),
                                selected: restSeconds == sec,
                                onSelected: busy
                                    ? null
                                    : (_) {
                                        setState(() => restSeconds = sec);
                                        persist();
                                      },
                              ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () {
                                      setState(
                                        () => restEnd = DateTime.now().add(
                                          Duration(seconds: restSeconds),
                                        ),
                                      );
                                      persist();
                                    },
                              child: const Text('Démarrer le repos'),
                            ),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () {
                                      setState(() => restEnd = null);
                                      persist();
                                    },
                              child: const Text('Arrêter'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (rows.isEmpty)
                  const Empty(
                    Icons.fitness_center,
                    'Ajoutez des exercices au programme pour commencer.',
                  ),
                for (var i = 0; i < rows.length; i++)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${rows[i]['name']} · Série ${rows[i]['set_number']}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text('Prévu : ${rows[i]['target']}'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: rows[i]['reps'],
                                  enabled: !busy && rows[i]['done'] != true,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Répétitions',
                                  ),
                                  onChanged: (v) {
                                    rows[i]['reps'] = v;
                                    persist();
                                  },
                                  validator: (v) => rows[i]['done'] != true
                                      ? null
                                      : ((int.tryParse(v ?? '') ?? 0) < 1 ||
                                                (int.tryParse(v ?? '') ?? 0) >
                                                    1000
                                            ? '1 à 1000'
                                            : null),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: rows[i]['weight'],
                                  enabled: !busy && rows[i]['done'] != true,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  decoration: const InputDecoration(
                                    labelText: 'Charge (kg)',
                                  ),
                                  onChanged: (v) {
                                    rows[i]['weight'] = v;
                                    persist();
                                  },
                                  validator: (v) {
                                    if (rows[i]['done'] != true) return null;
                                    final n = double.tryParse(
                                      (v ?? '').replaceAll(',', '.'),
                                    );
                                    return n == null ||
                                            !n.isFinite ||
                                            n < 0 ||
                                            n > 1000
                                        ? '0 à 1000 kg'
                                        : null;
                                  },
                                ),
                              ),
                            ],
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Série réalisée'),
                            value: rows[i]['done'] == true,
                            onChanged: busy
                                ? null
                                : (v) {
                                    final reps = int.tryParse(rows[i]['reps']);
                                    final weight = double.tryParse(
                                      (rows[i]['weight'] as String).replaceAll(
                                        ',',
                                        '.',
                                      ),
                                    );
                                    if (v == true &&
                                        (reps == null ||
                                            reps < 1 ||
                                            reps > 1000 ||
                                            weight == null ||
                                            !weight.isFinite ||
                                            weight < 0 ||
                                            weight > 1000 ||
                                            !RegExp(
                                              r'^\d+(?:[.,]\d{1,2})?$',
                                            ).hasMatch(rows[i]['weight']))) {
                                      setState(
                                        () => error =
                                            'Renseignez les répétitions et une charge valide (deux décimales maximum).',
                                      );
                                      return;
                                    }
                                    setState(() {
                                      rows[i]['done'] = v;
                                      error = null;
                                      if (v == true)
                                        restEnd = DateTime.now().add(
                                          Duration(seconds: restSeconds),
                                        );
                                    });
                                    persist();
                                  },
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: busy || rows.isEmpty ? null : finish,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(
                    busy ? 'Enregistrement…' : 'Terminer et enregistrer',
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
