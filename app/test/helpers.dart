import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ironfit/services/api_service.dart';
import 'package:ironfit/services/token_store.dart';

/// Faux serveur : renvoie [routes]['GET me'] etc. ; les listes inconnues renvoient [].
MockClient fakeServer(Map<String, Object?> routes, {List<http.Request>? log}) => MockClient((req) async {
      log?.add(req);
      final key = '${req.method} ${req.url.path.replaceFirst('/api/', '')}';
      final body = routes.containsKey(key) ? routes[key] : (req.method == 'GET' ? <Object>[] : {'ok': true});
      if (body is http.Response) return body;
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
    });

const admin = {'id': 1, 'name': 'Administrateur', 'login': 'admin', 'email': 'admin@ironfit.local', 'role': 'admin', 'active': 1};
const coach = {'id': 2, 'name': 'Sami Ben Ali', 'login': 'sami', 'email': 'sami@ironfit.local', 'role': 'coach', 'specialty': 'Musculation', 'active': 1};
const athlete = {'id': 4, 'name': 'Youssef Karray', 'login': 'youssef', 'email': 'youssef@ironfit.local', 'role': 'athlete', 'plan_id': 2, 'sub_end': '2099-01-31', 'active': 1};

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
