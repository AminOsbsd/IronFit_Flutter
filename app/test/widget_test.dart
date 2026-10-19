import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/app.dart';
import 'package:ironfit/core/api/api.dart';
import 'package:ironfit/core/api/token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('IronFit starts on the login screen', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    Api.store = MemoryTokenStore();
    await Api.init();

    await tester.pumpWidget(const IronFitApp());

    expect(find.text('IronFit'), findsOneWidget);
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('the sign-up form validates its fields before calling the server', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    Api.store = MemoryTokenStore();
    await Api.init();
    await tester.pumpWidget(const IronFitApp());

    await tester.tap(find.text('Pas de compte ? S\'inscrire'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('S\'inscrire'));
    await tester.pump();

    expect(find.text('Obligatoire'), findsNWidgets(4));
  });
}
