import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/api_service.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  runApp(const IronFitApp());
}

ThemeData _theme(Brightness b) => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF5A1F), brightness: b),
    );

class IronFitApp extends StatelessWidget {
  const IronFitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Api.authChanged,
      builder: (_, _, _) => MaterialApp(
        title: 'IronFit',
        debugShowCheckedModeBanner: false,
        navigatorKey: Api.navKey,
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Api.me == null ? const AuthPage() : const HomeShell(),
      ),
    );
  }
}
