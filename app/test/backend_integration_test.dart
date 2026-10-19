@Tags(['integration'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ironfit/core/api/api.dart';
import 'package:ironfit/core/api/token_store.dart';

// Intégration Flutter ↔ serveur : lance le vrai backend Node (base temporaire) et l'interroge
// avec le client Api de l'application. Ignoré si Node.js n'est pas installé.
//   flutter test test/backend_integration_test.dart

String? _nodeMissing() {
  try {
    return Process.runSync('node', ['--version']).exitCode == 0 ? null : 'Node.js introuvable';
  } catch (_) {
    return 'Node.js introuvable';
  }
}

void main() {
  // Binding nécessaire à Api.logout (navigateur) ; on rétablit ensuite les vraies requêtes HTTP
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  final skip = _nodeMissing();
  late Process server;
  late Directory data;

  setUpAll(() async {
    if (skip != null) return;
    data = await Directory.systemTemp.createTemp('ironfit-it-');
    server = await Process.start(
      'node',
      ['server.js'],
      workingDirectory: '../backend',
      environment: {
        'DATA_DIR': data.path,
        'PORT': '0',
        'HOST': '127.0.0.1',
        'RATE_LIMIT': '1000',
        'SEED_DEMO': 'true',
        'ADMIN_PASSWORD': 'admin123',
      },
    );
    final port = Completer<String>();
    server.stdout.transform(utf8.decoder).listen((s) {
      final m = RegExp(r'localhost:(\d+)').firstMatch(s);
      if (m != null && !port.isCompleted) port.complete(m.group(1));
    });
    server.stderr.transform(utf8.decoder).listen(printOnFailure);
    Api.base = 'http://127.0.0.1:${await port.future.timeout(const Duration(seconds: 20))}';
    Api.client = http.Client();
    Api.store = MemoryTokenStore();
  });

  tearDownAll(() async {
    if (skip != null) return;
    server.kill();
    await server.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
    try {
      await data.delete(recursive: true);
    } catch (_) {}
  });

  Future<void> loginAs(String login, [String password = '1234']) async =>
      Api.setSession(await Api.call('POST', 'login', {'login': login, 'password': password}) as Map);

  test('connexion par rôle et refus des actions non autorisées', () async {
    await expectLater(
      Api.call('POST', 'login', {'login': 'youssef', 'password': 'faux'}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Identifiant ou mot de passe incorrect')),
    );
    await loginAs('youssef');
    expect(Api.isMember, isTrue);
    await expectLater(Api.call('GET', 'members'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
    expect(Api.token, isNotNull, reason: 'un 403 ne déconnecte pas');
  }, skip: skip);

  test('parcours coach ↔ client : demande, programme, séance, commentaire, notifications', () async {
    await loginAs('sami');
    expect(Api.isCoach && Api.isMember, isTrue);
    final pending = (await Api.list('coaching/clients')).firstWhere((l) => l['client_login'] == 'amira');
    await Api.call('POST', 'coaching/${pending['id']}/accept');
    final prog =
        await Api.call('POST', 'programs', {'title': 'Cardio débutant', 'client_id': pending['client_id']}) as Map;
    await Api.call('POST', 'programs/${prog['id']}/exercises', {'name': 'Rameur', 'sets': 3, 'reps': '5 min'});

    await loginAs('amira');
    final mine = await Api.list(Api.withQuery('programs', {'scope': 'personal'}));
    expect(mine.map((p) => p['title']), contains('Cardio débutant'));
    final detail = await Api.get('programs/${prog['id']}');
    expect(detail['can_edit'], isFalse);
    expect(detail['can_log'], isTrue);
    final w = await Api.call('POST', 'workouts', {'program_id': prog['id'], 'duration': 25, 'rpe': 5}) as Map;

    await loginAs('sami');
    await Api.call('POST', 'workouts/${w['id']}/feedback', {'comment': 'Très bien, continue !'});

    await loginAs('amira');
    final notes = await Api.get('notifications');
    expect(
      jsonList(notes, 'items').map((n) => n['title']),
      containsAll(['Demande de coaching acceptée', 'Nouveau programme', 'Nouveau commentaire de votre coach']),
    );
  }, skip: skip);

  test('désactivation par l\'admin : la session du membre est coupée côté client', () async {
    await loginAs('youssef');
    final youssefToken = Api.token!;
    final id = Api.myId;
    await loginAs('admin', 'admin123');
    await Api.call('POST', 'members/$id/status', {'active': false});

    await Api.setToken(youssefToken);
    await expectLater(Api.call('GET', 'me'), throwsA(isA<ApiException>()));
    expect(Api.token, isNull, reason: 'un 401 doit déconnecter l\'application');

    await loginAs('admin', 'admin123');
    await Api.call('POST', 'members/$id/status', {'active': true});
  }, skip: skip);
}
