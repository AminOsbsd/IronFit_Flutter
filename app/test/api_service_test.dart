import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ironfit/core/config/app_config.dart';
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/core/network/token_store.dart';
import 'package:ironfit/services/auth_service.dart';
import 'package:ironfit/services/planning_service.dart';
import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('withQuery ignore les valeurs vides et encode les paramètres', () {
    expect(Api.withQuery('members', {'q': 'élan vital', 'role': null, 'limit': 50, 'x': ''}), 'members?q=%C3%A9lan+vital&limit=50');
    expect(Api.withQuery('programs?scope=coaching', {'client_id': 3}), 'programs?scope=coaching&client_id=3');
    expect(Api.withQuery('plans', {}), 'plans');
  });

  test('adresse de l\'API : port 8080 + /api, normalisation des saisies', () {
    expect(AppConfig.defaultApiBase, endsWith(':8080/api'));
    expect(AppConfig.normalizeBase('192.168.1.10:8080'), 'http://192.168.1.10:8080/api');
    expect(AppConfig.normalizeBase('http://localhost:8080/api/'), 'http://localhost:8080/api');
  });

  test('une ancienne adresse (serveur Node sur :3000) est remplacée par celle du backend Spring Boot', () async {
    SharedPreferences.setMockInitialValues({'base': 'http://127.0.0.1:3000'});
    Api.store = MemoryTokenStore();
    await Api.init();
    expect(Api.base, AppConfig.defaultApiBase);
  });

  test('le jeton est envoyé en en-tête Bearer et la session est restaurée au démarrage', () async {
    final log = <http.Request>[];
    SharedPreferences.setMockInitialValues({});
    Api.store = MemoryTokenStore('abc');
    Api.client = fakeServer({'GET me': athlete}, log: log);
    await Api.init();
    expect(Api.user?.login, 'youssef');
    expect(log.single.headers['Authorization'], 'Bearer abc');
    expect(log.single.url.toString(), '${AppConfig.defaultApiBase}/me');
    expect(Api.isMember, isTrue);
    expect(Api.isCoach, isFalse);
    expect(Api.user!.hasActiveSubscription, isTrue);
  });

  test('un ancien jeton stocké en clair est migré vers le stockage sécurisé', () async {
    SharedPreferences.setMockInitialValues({'token': 'ancien'});
    final store = MemoryTokenStore();
    Api.store = store;
    Api.client = fakeServer({'GET me': athlete});
    await Api.init();
    expect(store.token, 'ancien');
    expect(Api.prefs.getString('token'), isNull);
  });

  test('le message d\'erreur du serveur est remonté ; un 401 déconnecte', () async {
    await signedIn(athlete, {'POST book': http.Response.bytes(utf8.encode('{"error":"Séance complète","status":409}'), 409)});
    await expectLater(PlanningService.toggleBooking(1), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Séance complète')));

    // corps illisible : le code 401 suffit pour déconnecter
    Api.client = MockClient((_) async => http.Response('{"error":"Session expirée"}', 401));
    await expectLater(Api.call('GET', 'me'), throwsA(isA<ApiException>()));
    expect(Api.user, isNull);
    expect(Api.token, isNull);
    expect(await Api.store.read(), isNull);
  });

  test('serveur injoignable → message lisible sans détail technique', () async {
    await signedIn(athlete);
    Api.client = MockClient((_) async => throw Exception('SocketException: secret interne'));
    await expectLater(
      Api.call('GET', 'classes'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', allOf(contains('Serveur injoignable'), isNot(contains('secret'))))),
    );
  });

  test('un coach est aussi membre ; l\'espace choisi est mémorisé', () async {
    await signedIn(coach);
    expect(Api.isMember && Api.isCoach, isTrue);
    expect(Api.inCoachSpace, isFalse);
    await Api.setWorkspace(Workspace.coach);
    expect(Api.inCoachSpace, isTrue);
    expect(Api.prefs.getString('workspace'), 'coach');
  });

  test('changer de mot de passe remplace le jeton stocké', () async {
    await signedIn(athlete, {'POST password': {'ok': true, 'token': 'nouveau'}});
    await AuthService.changePassword('1234', 'abcdef');
    expect(await Api.store.read(), 'nouveau');
    expect(Api.token, 'nouveau');
  });

  test('mot de passe oublié : le code de démonstration (dev_code) est renvoyé', () async {
    await signedIn(athlete, {'POST forgot': {'ok': true, 'dev_code': '123456'}});
    expect(await AuthService.forgotPassword('youssef@ironfit.local'), '123456');
  });
}
