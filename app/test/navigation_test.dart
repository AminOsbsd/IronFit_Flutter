import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/core/theme/brand.dart';
import 'package:ironfit/main.dart';
import 'package:ironfit/models/module.dart';
import 'helpers.dart';

void main() {
  Future<void> open(WidgetTester tester, {double width = 420, double height = 900}) async {
    useScreen(tester, width: width, height: height);
    await tester.pumpWidget(const IronFitApp());
    await tester.pumpAndSettle();
  }

  List<String> tabs(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations.map((d) => (d as NavigationDestination).label).toList();

  testWidgets('un membre voit l\'espace membre, sans administration ni bascule coach', (tester) async {
    await signedIn(athlete);
    await open(tester);
    expect(tabs(tester), ['Accueil', 'Planning', 'Explorer', 'Mon espace', 'Profil']);
    expect(find.text('Espace coach'), findsNothing);
    expect(find.text('Bonjour, Youssef 👋'), findsOneWidget);
    expect(find.text('CARTE MEMBRE'), findsOneWidget);
    expect(find.byType(Badge), findsOneWidget); // cloche des notifications (2 non lues)
    expect(find.byType(BrandBackdrop), findsWidgets); // filigrane du logo derrière la page
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
        {'id': 9, 'coach_id': 2, 'client_id': 5, 'status': 'pending', 'client_name': 'Amira Jlassi', 'client_login': 'amira', 'created': '2026-10-01T10:00:00Z'},
      ],
    });
    await open(tester);
    // Par défaut : son entraînement personnel (il est aussi membre)
    expect(tabs(tester), ['Accueil', 'Planning', 'Explorer', 'Mon espace', 'Profil']);
    expect(find.text('CARTE MEMBRE · COACH'), findsOneWidget);

    await tester.tap(find.text('Espace coach'));
    await tester.pumpAndSettle();
    expect(tabs(tester), ['Accueil', 'Planning', 'Clients', 'Gestion', 'Profil']);
    expect(find.text('Demandes de suivi'), findsOneWidget);
    expect(find.text('Amira Jlassi'), findsOneWidget);
    expect(find.textContaining('2026-10-01'), findsOneWidget); // date ISO du serveur affichée sans l'heure
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

  testWidgets('grand écran : rail latéral avec le logo et bascule coach verticale', (tester) async {
    await signedIn(coach);
    await open(tester, width: 1300, height: 900);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BrandLogo), findsOneWidget);
    expect(find.byTooltip('Espace coach'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
