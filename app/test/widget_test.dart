import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ironfit/core/config/app_config.dart';
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/core/network/token_store.dart';
import 'package:ironfit/core/theme/brand.dart';
import 'package:ironfit/main.dart';
import 'helpers.dart';

void main() {
  Future<void> openLogin(WidgetTester tester, {double width = 420}) async {
    useScreen(tester, width: width);
    SharedPreferences.setMockInitialValues({});
    Api.store = MemoryTokenStore();
    await Api.init();
    await tester.pumpWidget(const IronFitApp());
    await tester.pumpAndSettle();
  }

  testWidgets('l\'écran de connexion affiche le logo officiel et le formulaire', (tester) async {
    await openLogin(tester);
    expect(find.byType(BrandLogo), findsOneWidget);
    final logo = tester.widget<Image>(find.descendant(of: find.byType(BrandLogo), matching: find.byType(Image)));
    expect((logo.image as ResizeImage).imageProvider, isA<AssetImage>().having((a) => a.assetName, 'asset', AppConfig.logo));
    expect(logo.fit, BoxFit.contain); // proportions conservées
    expect(find.text('Connexion'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
  });

  testWidgets('sur grand écran, le logo occupe un panneau dédié à côté du formulaire', (tester) async {
    await openLogin(tester, width: 1300);
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.text('Salle · Coaching · Suivi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('le formulaire d\'inscription valide les champs avant d\'appeler le serveur', (tester) async {
    await openLogin(tester);
    await tester.tap(find.text('S\'inscrire'));
    await tester.pumpAndSettle();
    final submit = find.widgetWithText(FilledButton, 'S\'inscrire');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();
    expect(find.text('Obligatoire'), findsNWidgets(4));
  });
}
