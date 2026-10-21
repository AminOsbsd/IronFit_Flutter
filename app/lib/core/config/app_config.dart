import 'package:flutter/foundation.dart';

/// Configuration centrale : adresse de l'API, délais, ressources.
class AppConfig {
  AppConfig._();

  /// Port du backend Spring Boot.
  static const apiPort = 8080;

  /// Délai maximal d'une requête réseau.
  static const requestTimeout = Duration(seconds: 15);

  static const logo = 'assets/images/ironfit_logo.png';
  static const logoTransparent = 'assets/images/ironfit_logo_transparent.png';

  /// Adresse de l'API selon la plateforme (modifiable dans l'application : roue dentée / Profil).
  ///  - Émulateur Android : 10.0.2.2 désigne le PC hôte
  ///  - Web : même machine que la page
  ///  - Windows / Linux / macOS : localhost
  ///  - Téléphone réel : saisir http://IP-DU-PC:8080/api dans l'application
  static String get defaultApiBase {
    if (kIsWeb) return 'http://${Uri.base.host.isEmpty ? 'localhost' : Uri.base.host}:$apiPort/api';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:$apiPort/api';
    return 'http://localhost:$apiPort/api';
  }

  /// Normalise une adresse saisie : sans « / » final, avec le suffixe /api.
  static String normalizeBase(String input) {
    var b = input.trim().replaceAll(RegExp(r'/+$'), '');
    if (b.isEmpty) return defaultApiBase;
    if (!b.startsWith('http://') && !b.startsWith('https://')) b = 'http://$b';
    if (!b.endsWith('/api')) b = '$b/api';
    return b;
  }
}
