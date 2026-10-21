import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/app_user.dart';
import '../config/app_config.dart';
import 'token_store.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Espace affiché pour un coach : son entraînement personnel ou son activité de coach.
enum Workspace { personal, coach }

/// Client REST vers le backend Spring Boot : adresse, jeton JWT, session, gestion des erreurs.
/// Les écrans passent par les services de lib/services/ plutôt que d'appeler directement ces méthodes.
class Api {
  static String base = AppConfig.defaultApiBase;
  static String? token;
  static AppUser? user;
  static late SharedPreferences prefs;
  static http.Client client = http.Client();
  static TokenStore store = SecureTokenStore();
  static Duration timeout = AppConfig.requestTimeout;
  static final navKey = GlobalKey<NavigatorState>();
  static final ValueNotifier<int> authChanged = ValueNotifier(0);
  static final ValueNotifier<Workspace> workspace = ValueNotifier(Workspace.personal);
  static final ValueNotifier<int> unread = ValueNotifier(0);

  // ---------- Rôles ----------
  // Les droits réels sont vérifiés par le serveur ; ces raccourcis adaptent uniquement l'interface.
  static String get role => user?.role ?? '';
  static int? get myId => user?.id;
  static bool get isAdmin => user?.isAdmin ?? false;
  static bool get isCoach => user?.isCoach ?? false;
  static bool get isMember => user?.isMember ?? false;
  /// Coach actuellement dans son espace professionnel.
  static bool get inCoachSpace => isCoach && workspace.value == Workspace.coach;

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('base');
    // Anciennes versions : serveur Node.js sur le port 3000, sans le suffixe /api
    base = (saved == null || saved.contains(':3000') || !saved.endsWith('/api')) ? AppConfig.defaultApiBase : saved;
    workspace.value = prefs.getString('workspace') == 'coach' ? Workspace.coach : Workspace.personal;
    // Anciennes versions : jeton stocké en clair dans les préférences -> migré vers le stockage sécurisé
    final legacy = prefs.getString('token');
    if (legacy != null) {
      await store.write(legacy);
      await prefs.remove('token');
    }
    token = await store.read();
    if (token != null) {
      try {
        await refreshMe();
      } catch (_) {}
    }
  }

  static Future<void> setBase(String b) async {
    base = AppConfig.normalizeBase(b);
    await prefs.setString('base', base);
  }

  static Future<void> setWorkspace(Workspace w) async {
    workspace.value = w;
    await prefs.setString('workspace', w.name);
  }

  /// Construit « chemin?clé=valeur » en ignorant les valeurs nulles ou vides.
  static String withQuery(String path, Map<String, Object?> q) {
    final p = {for (final e in q.entries) if (e.value != null && '${e.value}' != '') e.key: '${e.value}'};
    return p.isEmpty ? path : '$path${path.contains('?') ? '&' : '?'}${Uri(queryParameters: p).query}';
  }

  static Future<dynamic> call(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$base/$path');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final enc = body == null ? null : jsonEncode(body);
    http.Response r;
    try {
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
      throw ApiException('Serveur injoignable ($base). Vérifiez l\'adresse et que le backend Spring Boot est lancé.');
    }
    dynamic data;
    try {
      data = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      // Corps illisible : sur une erreur, le code HTTP suffit (un 401 doit quand même déconnecter)
      if (r.statusCode < 400) throw ApiException('Réponse inattendue du serveur (${r.statusCode}). Vérifiez l\'adresse du serveur.', r.statusCode);
    }
    if (r.statusCode >= 400) {
      if (r.statusCode == 401 && token != null) await logout();
      throw ApiException((data is Map ? data['error'] : null) ?? 'Erreur ${r.statusCode}', r.statusCode);
    }
    return data;
  }

  static Future<List<Map<String, dynamic>>> list(String endpoint) async =>
      ((await call('GET', endpoint)) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  static Future<Map<String, dynamic>> get(String endpoint) async => Map<String, dynamic>.from(await call('GET', endpoint) as Map);

  static Future<Map<String, dynamic>> post(String endpoint, [Map<String, dynamic>? body]) async =>
      Map<String, dynamic>.from((await call('POST', endpoint, body ?? const {})) as Map? ?? const {});

  static Future<void> put(String endpoint, Map<String, dynamic> body) => call('PUT', endpoint, body);

  static Future<void> delete(String endpoint) => call('DELETE', endpoint);

  static Future<void> refreshMe() async => user = AppUser.fromJson(await get('me'));

  static Future<void> setToken(String t) async {
    token = t;
    await store.write(t);
  }

  static Future<void> setSession(Map r) async {
    await setToken(r['token'] as String);
    user = AppUser.fromJson(Map<String, dynamic>.from(r['user'] as Map));
    authChanged.value++;
  }

  static Future<void> logout() async {
    token = null;
    user = null;
    unread.value = 0;
    await store.write(null);
    navKey.currentState?.popUntil((r) => r.isFirst);
    authChanged.value++;
  }
}
