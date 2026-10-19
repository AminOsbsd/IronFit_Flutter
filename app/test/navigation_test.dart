import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/app.dart';
import 'package:ironfit/core/api/api.dart';
import 'package:ironfit/features/crud/module_catalogue.dart';

import 'helpers.dart';

void main() {
  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const IronFitApp());
    await tester.pumpAndSettle();
  }

  NavigationBar navBar(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar));
  List<String> tabs(WidgetTester tester) =>
      navBar(tester).destinations.map((d) => (d as NavigationDestination).label).toList();

  testWidgets('un membre voit l\'espace membre, sans administration ni bascule coach', (tester) async {
    await signedIn(athlete);
    await open(tester);
    expect(tabs(tester), ['Accueil', 'Planning', 'Explorer', 'Mon espace', 'Profil']);
    expect(find.text('Espace coach'), findsNothing);
    expect(find.text('Bonjour, Youssef 👋'), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget); // cloche des notifications (2 non lues)
  });

  testWidgets('l\'administrateur a une interface d\'administration dédiée', (tester) async {
    await signedIn(admin);
    await open(tester);
    expect(tabs(tester), ['Accueil', 'Planning', 'Administration', 'Profil']);
    await tester.tap(find.text('Administration').last);
    await tester.pumpAndSettle();
    expect(find.text('Demandes d\'abonnement'), findsOneWidget);
    expect(find.text('Suivis coaching'), findsOneWidget);
    expect(find.text('Coachs'), findsOneWidget);
  });

  testWidgets('un coach bascule entre son entraînement et son espace coach', (tester) async {
    await signedIn(coach, {
      'GET coaching/clients': [
        {
          'id': 9,
          'coach_id': 2,
          'client_id': 5,
          'status': 'pending',
          'client_name': 'Amira Jlassi',
          'client_login': 'amira',
          'created': '2026-10-01 10:00:00',
        },
      ],
    });
    await open(tester);
    // Par défaut : son entraînement personnel (il est aussi membre)
    expect(tabs(tester), ['Accueil', 'Planning', 'Explorer', 'Mon espace', 'Profil']);
    expect(find.text('IRONFIT · CARTE MEMBRE · COACH'), findsOneWidget);

    await tester.tap(find.text('Espace coach'));
    await tester.pumpAndSettle();
    expect(tabs(tester), ['Accueil', 'Planning', 'Clients', 'Gestion', 'Profil']);
    expect(find.text('Demandes de suivi'), findsOneWidget);
    expect(find.text('Amira Jlassi'), findsOneWidget);
    expect(Api.prefs.getString('workspace'), 'coach');

    // Gestion : uniquement les modules qu'un coach peut modifier
    await tester.tap(find.text('Gestion'));
    await tester.pumpAndSettle();
    expect(find.text('Séances & réservations'), findsOneWidget);
    expect(find.text('Paiements'), findsNothing);
    expect(find.text('Membres'), findsNothing);

    await tester.tap(find.text('Mon entraînement'));
    await tester.pumpAndSettle();
    expect(tabs(tester), contains('Mon espace'));
  });

  group('règles d\'interface des modules', () {
    test('un coach ne modifie que ses propres séances et annonces ; le champ coach est réservé à l\'admin', () async {
      await signedIn(coach);
      final classes = moduleById('classes'), ann = moduleById('announcements');
      expect(classes.canEditRow!({'coach_id': 2}), isTrue);
      expect(classes.canEditRow!({'coach_id': 3}), isFalse);
      expect(ann.canEditRow!({'author_id': 1}), isFalse);
      expect(classes.fields.firstWhere((f) => f.key == 'coach_id').visible, isFalse);
      expect(moduleById('measures').query!(), {'scope': 'clients'});

      await signedIn(admin);
      expect(classes.canEditRow!({'coach_id': 3}), isTrue);
      expect(classes.fields.firstWhere((f) => f.key == 'coach_id').visible, isTrue);
    });
  });
}
