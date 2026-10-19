import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api/api.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_page.dart';
import 'features/shell/home_shell.dart';

/// Racine de l'app : thème, localisation, et page d'accueil selon la session.
class IronFitApp extends StatelessWidget {
  const IronFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IronFit',
      debugShowCheckedModeBanner: false,
      navigatorKey: Api.navKey,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      locale: const Locale('fr'),
      supportedLocales: const [Locale('fr'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: ValueListenableBuilder<int>(
        valueListenable: Api.authChanged,
        // La clé force la reconstruction complète quand l'utilisateur change.
        builder: (_, version, _) =>
            Api.me == null ? AuthPage(key: ValueKey('auth$version')) : HomeShell(key: ValueKey('home$version')),
      ),
    );
  }
}
