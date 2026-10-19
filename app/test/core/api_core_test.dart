import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ironfit/core/api/api.dart';
import 'package:ironfit/core/api/refs.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => Api.timeout = const Duration(seconds: 15));

  test('normalizeBase trims, strips trailing slashes and adds a missing scheme', () {
    expect(Api.normalizeBase('  http://192.168.1.5:3000/// '), 'http://192.168.1.5:3000');
    expect(Api.normalizeBase('192.168.1.5:3000'), 'http://192.168.1.5:3000');
    expect(Api.normalizeBase('https://gym.example'), 'https://gym.example');
  });

  test('setBase stores the normalised address', () async {
    await signedIn(athlete);
    await Api.setBase('10.0.2.2:3000/');
    expect(Api.base, 'http://10.0.2.2:3000');
    expect(Api.prefs.getString('base'), 'http://10.0.2.2:3000');
  });

  test('a request that hangs times out with a readable message', () async {
    await signedIn(athlete);
    Api.client = MockClient((_) => Completer<http.Response>().future);
    Api.timeout = const Duration(milliseconds: 20);
    await expectLater(
      Api.call('GET', 'plans'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('ne répond pas'))),
    );
  });

  test('a non-JSON success body is reported, a non-JSON error falls back to the status code', () async {
    await signedIn(athlete, {'GET stats': http.Response('<html>oops</html>', 200)});
    await expectLater(
      Api.call('GET', 'stats'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('Réponse inattendue'))),
    );
    Api.client = MockClient((_) async => http.Response('<html>Bad gateway</html>', 502));
    await expectLater(
      Api.call('GET', 'stats'),
      throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Erreur 502')),
    );
  });

  test('listOrEmpty swallows errors, list does not', () async {
    await signedIn(athlete, {'GET plans': http.Response('{"error":"boom"}', 500)});
    expect(await Api.listOrEmpty('plans'), isEmpty);
    await expectLater(Api.list('plans'), throwsA(isA<ApiException>()));
  });

  test('jsonList reads nested lists and tolerates missing keys', () {
    final m = <String, dynamic>{
      'items': [
        {'id': 1},
      ],
    };
    expect(jsonList(m, 'items').single['id'], 1);
    expect(jsonList(m, 'missing'), isEmpty);
  });

  group('Refs', () {
    test('admin loads plans, coaches and members in parallel and resolves names', () async {
      final log = <http.Request>[];
      await signedIn(admin);
      Api.client = fakeServer({
        'GET plans': [
          {'id': 1, 'name': 'Mensuel'},
        ],
        'GET coaches': [
          {'id': 2, 'name': 'Sami'},
        ],
        'GET members': [
          {'id': 4, 'name': 'Youssef'},
        ],
      }, log: log);
      await Refs.load();
      expect(log.map((r) => r.url.path), containsAll(['/api/plans', '/api/coaches', '/api/members']));
      expect(Refs.name('plans', 1), 'Mensuel');
      expect(Refs.name('plans', 99), '—');
      expect(Refs.name('plans', null), '—');
      expect(Refs.options('members'), {4: 'Youssef'});
    });

    test('a member does not request the member list and sees their own name', () async {
      final log = <http.Request>[];
      await signedIn(athlete);
      Api.client = fakeServer({}, log: log);
      await Refs.load();
      expect(log.map((r) => r.url.path), isNot(contains('/api/members')));
      expect(Refs.name('members', 4), 'Youssef Karray');
    });
  });

  test('refreshUnread keeps the previous count when the server fails', () async {
    await signedIn(athlete, {
      'GET notifications': {'unread': 3, 'items': <Object>[]},
    });
    await Api.refreshUnread();
    expect(Api.unread.value, 3);
    Api.client = MockClient((_) async => http.Response.bytes(utf8.encode('{"error":"down"}'), 500));
    await Api.refreshUnread();
    expect(Api.unread.value, 3);
  });
}
