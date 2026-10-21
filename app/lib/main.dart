import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  runApp(const IronFitApp());
}

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
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Api.user == null ? const AuthPage() : const HomeShell(),
      ),
    );
  }
}
