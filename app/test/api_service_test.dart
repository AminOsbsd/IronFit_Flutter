import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ironfit/core/api/api.dart';
import 'package:ironfit/core/api/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('withQuery ignore les valeurs vides et encode les paramètres', () {
    expect(
      Api.withQuery('members', {'q': 'élan vital', 'role': null, 'limit': 50, 'x': ''}),
      'members?q=%C3%A9lan+vital&limit=50',
    );
    expect(Api.withQuery('programs?scope=coaching', {'client_id': 3}), 'programs?scope=coaching&client_id=3');
    expect(Api.withQuery('plans', {}), 'plans');
  });

  test('le jeton est envoyé en en-tête Bearer et la session est restaurée au démarrage', () async {
    final log = <http.Request>[];
    SharedPreferences.setMockInitialValues({});
    Api.store = MemoryTokenStore('abc');
    Api.client = fakeServer({'GET me': athlete}, log: log);
    await Api.init();
    expect(Api.me?['login'], 'youssef');
    expect(log.single.headers['Authorization'], 'Bearer abc');
    expect(Api.isMember, isTrue);
    expect(Api.isCoach, isFalse);
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
    await signedIn(athlete, {'POST book': http.Response.bytes(utf8.encode('{"error":"Séance complète"}'), 409)});
    await expectLater(
      Api.call('POST', 'book', {'class_id': 1}),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Séance complète')),
    );

    Api.client = MockClient((_) async => http.Response('{"error":"Session expirée"}', 401));
    await expectLater(Api.call('GET', 'me'), throwsA(isA<ApiException>()));
    expect(Api.me, isNull);
    expect(Api.token, isNull);
    expect(await Api.store.read(), isNull);
  });

  test('serveur injoignable → message lisible sans détail technique', () async {
    await signedIn(athlete);
    Api.client = MockClient((_) async => throw Exception('SocketException: secret interne'));
    await expectLater(
      Api.call('GET', 'classes'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          allOf(contains('Serveur injoignable'), isNot(contains('secret'))),
        ),
      ),
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
    await signedIn(athlete);
    await Api.setToken('nouveau');
    expect(await Api.store.read(), 'nouveau');
  });
}
