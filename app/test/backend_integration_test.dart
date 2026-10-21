@Tags(['integration'])
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/core/network/token_store.dart';
import 'package:ironfit/services/auth_service.dart';
import 'package:ironfit/services/coach_service.dart';
import 'package:ironfit/services/notification_service.dart';
import 'package:ironfit/services/program_service.dart';

// Intégration Flutter ↔ backend Spring Boot + MySQL : les services de l'application interrogent un vrai serveur.
// Le serveur doit tourner sur une base de démonstration NEUVE (le test modifie des données) — voir README, « Tests ».
// Adresse : variable IRONFIT_API_URL (défaut http://localhost:8080/api). Tests ignorés si le serveur est injoignable.

final base = Platform.environment['IRONFIT_API_URL'] ?? 'http://localhost:8080/api';

Future<bool> _reachable() async {
  try {
    final uri = Uri.parse(base);
    final s = await Socket.connect(uri.host, uri.port, timeout: const Duration(seconds: 2));
    s.destroy();
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  // Binding nécessaire à Api.logout (navigateur) ; on rétablit ensuite les vraies requêtes HTTP
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null;
  var up = false;

  setUpAll(() async {
    up = await _reachable();
    Api.base = base;
    Api.client = http.Client();
    Api.store = MemoryTokenStore();
  });

  Future<void> loginAs(String login, [String password = '1234']) => AuthService.login(login, password);

  test('connexion par rôle et refus des actions non autorisées', () async {
    if (!up) return markTestSkipped('Backend injoignable sur $base');
    await expectLater(AuthService.login('youssef', 'faux'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Identifiant ou mot de passe incorrect')));
    await loginAs('youssef');
    expect(Api.isMember, isTrue);
    await expectLater(Api.list('members'), throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
    expect(Api.token, isNotNull, reason: 'un 403 ne déconnecte pas');
  });

  test('parcours coach ↔ client : demande, programme, séance, commentaire, notifications', () async {
    if (!up) return markTestSkipped('Backend injoignable sur $base');
    await loginAs('sami');
    expect(Api.isCoach && Api.isMember, isTrue);
    final pending = (await CoachService.clients()).firstWhere((l) => l['client_login'] == 'amira');
    await CoachService.answer(pending['id'] as int, accept: true);
    final pid = await ProgramService.create({'title': 'Cardio débutant'}, clientId: pending['client_id'] as int);
    await ProgramService.addExercise(pid, {'name': 'Rameur', 'sets': 3, 'reps': '5 min'});

    await loginAs('amira');
    final mine = await ProgramService.programs(scope: 'personal');
    expect(mine.map((p) => p['title']), contains('Cardio débutant'));
    final detail = await ProgramService.program(pid);
    expect(detail['can_edit'], isFalse);
    expect(detail['can_log'], isTrue);
    await ProgramService.logWorkout({'duration': 25, 'rpe': 5}, programId: pid);
    final workoutId = (await ProgramService.workouts()).first['id'] as int;

    await loginAs('sami');
    await ProgramService.comment(workoutId, 'Très bien, continue !');

    await loginAs('amira');
    final notes = await NotificationService.load();
    expect(notes.map((n) => n['title']), containsAll(['Demande de coaching acceptée', 'Nouveau programme', 'Nouveau commentaire de votre coach']));
  });

  test('désactivation par l\'admin : la session du membre est coupée côté client', () async {
    if (!up) return markTestSkipped('Backend injoignable sur $base');
    await loginAs('youssef');
    final youssefToken = Api.token!;
    final id = Api.myId!;
    await loginAs('admin', 'admin123');
    await Api.post('members/$id/status', {'active': false});

    await Api.setToken(youssefToken);
    await expectLater(Api.call('GET', 'me'), throwsA(isA<ApiException>()));
    expect(Api.token, isNull, reason: 'un 401 doit déconnecter l\'application');

    await loginAs('admin', 'admin123');
    await Api.post('members/$id/status', {'active': true});
  });
}
