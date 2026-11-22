import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/main.dart';
import 'package:ironfit/screens/membership_screen.dart';
import 'helpers.dart';

void main() {
  testWidgets('planning selection survives tab navigation without reloading', (
    tester,
  ) async {
    await signedIn(athlete);
    final log = <http.Request>[];
    Api.client = fakeServer({
      'GET me': athlete,
      'GET notifications': {'unread': 0, 'items': []},
    }, log: log);
    useScreen(tester);
    await tester.pumpWidget(const IronFitApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planning').last);
    await tester.pumpAndSettle();
    final short = [
      'Lun',
      'Mar',
      'Mer',
      'Jeu',
      'Ven',
      'Sam',
      'Dim',
    ][DateTime.now().weekday % 7];
    await tester.ensureVisible(find.text(short));
    await tester.tap(find.text(short));
    await tester.pumpAndSettle();
    final count = log.where((r) => r.url.path.endsWith('/classes')).length;
    await tester.tap(find.text('Accueil').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planning').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Demain ·'), findsOneWidget);
    expect(log.where((r) => r.url.path.endsWith('/classes')).length, count);
  });
  testWidgets('homepage identifies failed programs instead of empty programs', (
    tester,
  ) async {
    await signedIn(athlete, {
      'GET programs': http.Response('Unavailable', 503),
    });
    useScreen(tester);
    await tester.pumpWidget(const IronFitApp());
    await tester.pumpAndSettle();
    expect(find.text('Impossible de charger les programmes.'), findsOneWidget);
    expect(find.text('Aucun programme actif.'), findsNothing);
    expect(find.text('Réessayer'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('membership combines access and reception requests', (
    tester,
  ) async {
    await signedIn(
      {...athlete, 'plan_name': 'Mensuel'},
      {
        'GET requests': [
          {'id': 7, 'status': 'pending', 'plan_name': 'Annuel'},
        ],
      },
    );
    useScreen(tester, width: 360);
    await tester.pumpWidget(const MaterialApp(home: MembershipPage()));
    await tester.pumpAndSettle();
    expect(find.text('Mensuel'), findsOneWidget);
    expect(find.text('Accès actif'), findsOneWidget);
    expect(find.text('Annuel'), findsOneWidget);
    expect(find.text('Annuler la demande'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
