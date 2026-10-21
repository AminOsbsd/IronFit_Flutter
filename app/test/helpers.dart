import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/core/network/token_store.dart';

/// Faux serveur : renvoie routes['GET me'] etc. ; les listes inconnues renvoient [].
MockClient fakeServer(Map<String, Object?> routes, {List<http.Request>? log}) => MockClient((req) async {
      log?.add(req);
      final key = '${req.method} ${req.url.path.replaceFirst(RegExp(r'^/api/'), '')}';
      final body = routes.containsKey(key) ? routes[key] : (req.method == 'GET' ? <Object>[] : {'ok': true});
      if (body is http.Response) return body;
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
    });

const admin = {'id': 1, 'name': 'Administrateur', 'login': 'admin', 'email': 'admin@ironfit.local', 'role': 'admin', 'active': true};
const coach = {'id': 2, 'name': 'Sami Ben Ali', 'login': 'sami', 'email': 'sami@ironfit.local', 'role': 'coach', 'specialty': 'Musculation', 'active': true};
const athlete = {'id': 4, 'name': 'Youssef Karray', 'login': 'youssef', 'email': 'youssef@ironfit.local', 'role': 'athlete', 'plan_id': 2, 'sub_end': '2099-01-31', 'active': true};

/// Prépare une session connectée avec l'utilisateur [user] et un faux serveur.
Future<void> signedIn(Map<String, Object?> user, [Map<String, Object?> routes = const {}]) async {
  SharedPreferences.setMockInitialValues({});
  Api.store = MemoryTokenStore('jeton');
  Api.workspace.value = Workspace.personal;
  Api.client = fakeServer({
    'GET me': user,
    'GET stats': <String, Object?>{},
    'GET notifications': {'unread': 2, 'items': []},
    ...routes,
  });
  await Api.init();
}

/// Taille d'écran simulée (téléphone par défaut).
void useScreen(WidgetTester tester, {double width = 420, double height = 900}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
