import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'token_store.dart';

/// Objet JSON renvoyé par le serveur.
typedef Json = Map<String, dynamic>;

/// Liste d'objets JSON contenue dans [m] sous la clé [k] (vide si absente).
List<Json> jsonList(Json m, String k) =>
    ((m[k] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

/// Erreur lisible renvoyée par [Api.call] (message affichable tel quel).
class ApiException implements Exception {
  final String message;
  final int? status;
  const ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Espace affiché pour un coach : son entraînement personnel ou son activité de coach.
enum Workspace { personal, coach }

/// Client REST vers le serveur IronFit (Node + SQLite).
///
/// Porte la session (jeton, utilisateur courant) et trois [ValueNotifier] qui pilotent l'interface :
/// [authChanged] (connexion / déconnexion), [workspace] (espace du coach) et [unread] (notifications).
/// [client], [store] et [timeout] sont remplaçables dans les tests.
class Api {
  Api._();

  static String base = 'http://127.0.0.1:3000';
  static String? token;
  static Json? me;
  static late SharedPreferences prefs;
  static http.Client client = http.Client();
  static TokenStore store = SecureTokenStore();
  static Duration timeout = const Duration(seconds: 15);
  static final navKey = GlobalKey<NavigatorState>();
  static final ValueNotifier<int> authChanged = ValueNotifier(0);
  static final ValueNotifier<Workspace> workspace = ValueNotifier(Workspace.personal);
  static final ValueNotifier<int> unread = ValueNotifier(0);

  // ---------- Rôles ----------
  // Les droits réels sont vérifiés par le serveur ; ces raccourcis servent uniquement à adapter l'interface.
  static String get role => (me?['role'] as String?) ?? '';
  static int? get myId => me?['id'] as int?;
  static bool get isAdmin => role == 'admin';
  static bool get isCoach => role == 'coach';

  /// Un coach est aussi membre : il peut s'abonner, réserver et suivre ses programmes.
  static bool get isMember => role == 'athlete' || role == 'coach';

  /// Coach actuellement dans son espace professionnel.
  static bool get inCoachSpace => isCoach && workspace.value == Workspace.coach;

  /// Adresse par défaut selon la plateforme.
  static String get defaultBase {
    if (kIsWeb) return 'http://${Uri.base.host}:3000'; // Flutter Web
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000'; // émulateur Android -> PC
    return 'http://127.0.0.1:3000'; // Windows / Linux / macOS
  }

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('base');
    // 'http://localhost:3000' = ancienne valeur par défaut : on la remplace par la bonne adresse
    base = (saved == null || saved == 'http://localhost:3000') ? defaultBase : saved;
    workspace.value = prefs.getString('workspace') == 'coach' ? Workspace.coach : Workspace.personal;
    // Anciennes versions : le jeton était stocké en clair dans les préférences -> migration vers le stockage sécurisé
    final legacy = prefs.getString('token');
    if (legacy != null) {
      await store.write(legacy);
      await prefs.remove('token');
    }
    token = await store.read();
    if (token != null) {
      try {
        await refreshMe();
      } on ApiException {
        // Serveur injoignable ou jeton expiré : l'écran de connexion s'affichera.
      }
    }
  }

  /// Nettoie une adresse saisie : espaces, `/` final, schéma `http://` ajouté s'il manque.
  static String normalizeBase(String input) {
    var b = input.trim().replaceAll(RegExp(r'/+$'), '');
    if (b.isNotEmpty && !b.contains('://')) b = 'http://$b';
    return b;
  }

  static Future<void> setBase(String b) async {
    base = normalizeBase(b);
    await prefs.setString('base', base);
  }

  static Future<void> setWorkspace(Workspace w) async {
    workspace.value = w;
    await prefs.setString('workspace', w.name);
  }

  /// Construit « chemin?clé=valeur » en ignorant les valeurs nulles ou vides.
  static String withQuery(String path, Map<String, Object?> q) {
    final p = {
      for (final e in q.entries)
        if (e.value != null && '${e.value}' != '') e.key: '${e.value}',
    };
    return p.isEmpty ? path : '$path${path.contains('?') ? '&' : '?'}${Uri(queryParameters: p).query}';
  }

  static Future<dynamic> call(String method, String path, [Json? body]) async {
    final http.Response r;
    try {
      final uri = Uri.parse('$base/api/$path');
      final headers = {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'};
      final enc = body == null ? null : jsonEncode(body);
      final Future<http.Response> f = switch (method) {
        'POST' => client.post(uri, headers: headers, body: enc),
        'PUT' => client.put(uri, headers: headers, body: enc),
        'DELETE' => client.delete(uri, headers: headers),
        _ => client.get(uri, headers: headers),
      };
      r = await f.timeout(timeout);
    } on TimeoutException {
      throw ApiException('Le serveur ne répond pas ($base). Vérifiez votre connexion.');
    } catch (_) {
      // Pas de détail technique dans le message affiché (il peut contenir des informations internes).
      throw ApiException('Serveur injoignable ($base). Vérifiez l\'adresse et que le serveur est lancé.');
    }
    Object? data;
    try {
      data = r.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } on FormatException {
      // Corps illisible : sur une erreur, le code HTTP suffit (un 401 doit quand même déconnecter)
      if (r.statusCode < 400) {
        throw ApiException(
          'Réponse inattendue du serveur (${r.statusCode}). Vérifiez l\'adresse du serveur.',
          r.statusCode,
        );
      }
    }
    if (r.statusCode >= 400) {
      if (r.statusCode == 401 && token != null) await logout();
      final error = data is Map ? data['error'] as String? : null;
      if (r.statusCode == 404 && error == 'Route inconnue') {
        throw const ApiException(
          'Le serveur ne connaît pas cette fonction : il s\'agit sans doute d\'une ancienne version. '
          'Relancez 1-lancer-serveur.bat.',
          404,
        );
      }
      throw ApiException(error ?? 'Erreur ${r.statusCode}', r.statusCode);
    }
    return data;
  }

  static Future<List<Json>> list(String endpoint) async =>
      ((await call('GET', endpoint)) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  /// Comme [list], mais renvoie une liste vide en cas d'erreur.
  /// Réservé aux écrans qui agrègent plusieurs sources : un bloc vide vaut mieux qu'un écran d'erreur.
  static Future<List<Json>> listOrEmpty(String endpoint) async {
    try {
      return await list(endpoint);
    } on ApiException {
      return <Json>[];
    }
  }

  static Future<Json> get(String endpoint) async => Map<String, dynamic>.from(await call('GET', endpoint) as Map);

  static Future<void> refreshMe() async => me = await get('me');

  static Future<void> setToken(String t) async {
    token = t;
    await store.write(t);
  }

  static Future<void> setSession(Map<dynamic, dynamic> r) async {
    await setToken(r['token'] as String);
    me = Map<String, dynamic>.from(r['user'] as Map);
    authChanged.value++;
  }

  static Future<void> logout() async {
    token = null;
    me = null;
    unread.value = 0;
    await store.write(null);
    navKey.currentState?.popUntil((r) => r.isFirst);
    authChanged.value++;
  }

  /// Met à jour le compteur de notifications non lues (silencieux en cas d'erreur).
  static Future<void> refreshUnread() async {
    try {
      unread.value = ((await get(withQuery('notifications', {'limit': 1})))['unread'] as int?) ?? 0;
    } on ApiException {
      // La pastille garde sa valeur précédente.
    }
  }
}
