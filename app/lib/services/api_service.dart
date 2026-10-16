import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  final int? status;
  ApiException(this.message, [this.status]);
  @override
  String toString() => message;
}

/// Client REST vers le serveur IronFit (Node + SQLite).
class Api {
  static String base = 'http://127.0.0.1:3000';
  static String? token;
  static Map<String, dynamic>? me;
  static late SharedPreferences prefs;
  static final navKey = GlobalKey<NavigatorState>();
  static final ValueNotifier<int> authChanged = ValueNotifier(0);

  static String get role => (me?['role'] ?? '') as String;

  /// Adresse par défaut selon la plateforme.
  static String get defaultBase {
    if (kIsWeb) return 'http://${Uri.base.host}:3000'; // Flutter Web (Chrome)
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000'; // émulateur Android -> PC
    return 'http://127.0.0.1:3000'; // Windows / Linux / macOS
  }

  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    final saved = prefs.getString('base');
    // 'http://localhost:3000' = ancienne valeur par défaut : on la remplace par la bonne adresse
    base = (saved == null || saved == 'http://localhost:3000') ? defaultBase : saved;
    if (token != null) {
      try {
        me = Map<String, dynamic>.from(await call('GET', 'me') as Map);
      } catch (_) {}
    }
  }

  static Future<void> setBase(String b) async {
    base = b.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString('base', base);
  }

  static Future<dynamic> call(String method, String path, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$base/api/$path');
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final enc = body == null ? null : jsonEncode(body);
    http.Response r;
    try {
      switch (method) {
        case 'POST':
          r = await http.post(uri, headers: headers, body: enc);
          break;
        case 'PUT':
          r = await http.put(uri, headers: headers, body: enc);
          break;
        case 'DELETE':
          r = await http.delete(uri, headers: headers);
          break;
        default:
          r = await http.get(uri, headers: headers);
      }
    } catch (e) {
      throw ApiException('Serveur injoignable ($base). Vérifiez l\'adresse et que le serveur est lancé.\n[$e]');
    }
    final data = r.body.isEmpty ? null : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      if (r.statusCode == 401 && token != null) await logout();
      if (r.statusCode == 404 && data is Map && data['error'] == 'Route inconnue') {
        throw ApiException('Le serveur en cours est une ancienne version. Fermez-le (Ctrl+C), puis relancez 1-lancer-serveur.bat depuis le dossier du dernier zip.', 404);
      }
      throw ApiException((data is Map ? data['error'] : null) ?? 'Erreur ${r.statusCode}', r.statusCode);
    }
    return data;
  }

  static Future<List<Map<String, dynamic>>> list(String endpoint) async =>
      ((await call('GET', endpoint)) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  static Future<void> setSession(Map r) async {
    token = r['token'] as String;
    me = Map<String, dynamic>.from(r['user'] as Map);
    await prefs.setString('token', token!);
    authChanged.value++;
  }

  static Future<void> logout() async {
    token = null;
    me = null;
    await prefs.remove('token');
    navKey.currentState?.popUntil((r) => r.isFirst);
    authChanged.value++;
  }
}
