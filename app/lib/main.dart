import 'widgets/member_design.dart';
import 'screens/stripe_payments_screen.dart';
import 'screens/launch_splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'screens/auth_screen.dart';
import 'screens/home_shell.dart';

String? paymentReturnOrder(Uri uri) {
  final order = uri.queryParameters['payment_order'];
  return order != null && RegExp(r'^[a-zA-Z0-9-]{1,100}$').hasMatch(order)
      ? order
      : null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(IronFitApp(initialize: Api.init));
}

class IronFitApp extends StatelessWidget {
  // Null supports hosts/tests that have already initialized the session.
  final Future<void> Function()? initialize;
  const IronFitApp({super.key, this.initialize});

  Widget _destination() {
    if (Api.user == null) return const AuthPage();
    final order = paymentReturnOrder(Uri.base);
    if (order != null) {
      return StripePaymentsPage(orderId: order);
    }
    return const HomeShell();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Api.authChanged,
      builder: (_, _, _) => MaterialApp(
        title: 'IronFit',
        debugShowCheckedModeBanner: false,
        navigatorKey: Api.navKey,
        theme: isMemberDesign
            ? memberTheme(AppTheme.light())
            : AppTheme.light(),
        darkTheme: isMemberDesign
            ? memberTheme(AppTheme.dark())
            : AppTheme.dark(),
        themeMode: ThemeMode.system,
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: initialize == null
            ? _destination()
            : LaunchSplash(
                initialize: initialize!,
                skipAnimation: Uri.base.queryParameters.containsKey(
                  'payment_return',
                ),
                destination: (_) => _destination(),
              ),
      ),
    );
  }
}
