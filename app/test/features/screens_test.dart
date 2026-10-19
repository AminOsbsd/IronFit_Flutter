import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ironfit/core/api/api.dart';
import 'package:ironfit/core/theme/app_colors.dart';
import 'package:ironfit/core/theme/app_theme.dart';
import 'package:ironfit/features/coach/clients_page.dart';
import 'package:ironfit/features/coaching/coaches_tab.dart';
import 'package:ironfit/features/crud/crud_page.dart';
import 'package:ironfit/features/crud/module_catalogue.dart';
import 'package:ironfit/features/member/member_home_page.dart';
import 'package:ironfit/features/member/subscription.dart';
import 'package:ironfit/features/notifications/notifications_page.dart';
import 'package:ironfit/features/planning/participants_page.dart';
import 'package:ironfit/features/planning/planning_page.dart';

import '../helpers.dart';

Future<void> pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), navigatorKey: Api.navKey, home: page));
  await tester.pumpAndSettle();
}

/// Contraste WCAG entre deux couleurs opaques.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  group('regressions: empty names no longer crash', () {
    testWidgets('class participants', (tester) async {
      await signedIn(admin, {
        'GET classes/4/participants': [
          {'id': 7, 'name': '', 'present': 0},
        ],
      });
      await pumpPage(tester, const ParticipantsPage({'id': 4, 'day': 0, 'title': 'Crossfit', 'time': '18:00'}));
      expect(tester.takeException(), isNull);
      expect(find.text('?'), findsOneWidget);
    });

    testWidgets('coach clients', (tester) async {
      await signedIn(coach, {
        'GET coaching/clients': [
          {'id': 9, 'client_id': 5, 'status': 'active', 'client_name': '', 'client_sub_end': null},
        ],
      });
      await pumpPage(tester, const ClientsPage());
      expect(tester.takeException(), isNull);
      expect(find.text('Sans abonnement · Dernière séance : —'), findsOneWidget);
    });

    testWidgets('coach directory', (tester) async {
      await signedIn(athlete, {
        'GET coaches': [
          {'id': 3, 'name': '', 'specialty': 'Yoga', 'classes': 2},
        ],
      });
      await pumpPage(tester, const Scaffold(body: CoachesTab()));
      expect(tester.takeException(), isNull);
      expect(find.text('Demander'), findsOneWidget);
    });
  });

  testWidgets('member card: malformed end date does not crash, text contrast >= 4.5:1', (tester) async {
    await signedIn(athlete);
    final me = {...athlete, 'sub_end': 'n/a'};
    await pumpPage(
      tester,
      Scaffold(
        body: MemberCard(me: me, status: SubscriptionStatus.of('n/a')),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Date de fin invalide'), findsOneWidget);
    for (final g in [AppColors.brandGradient, AppColors.inactiveGradient]) {
      for (final c in g) {
        expect(contrast(Colors.white, c), greaterThanOrEqualTo(4.5), reason: '$c');
      }
    }
  });

  testWidgets('notifications: leaving while a notification is being marked read does not throw', (tester) async {
    final semantics = tester.ensureSemantics();
    await signedIn(athlete);
    final pending = Completer<http.Response>();
    final list = {
      'unread': 1,
      'items': [
        {'id': 1, 'title': 'Nouveau programme', 'body': null, 'seen': 0, 'created': '2026-10-19 08:00:00'},
      ],
    };
    Api.client = MockClient(
      (req) async => req.method == 'POST' ? pending.future : http.Response.bytes(utf8.encode(jsonEncode(list)), 200),
    );
    await pumpPage(tester, const Scaffold(body: Text('Accueil')));
    unawaited(Api.navKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => const NotificationsPage())));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('Non lue')), findsOneWidget);

    await tester.tap(find.text('Nouveau programme'));
    await tester.pump();
    Api.navKey.currentState!.pop();
    await tester.pumpAndSettle();
    pending.complete(http.Response.bytes(utf8.encode('{"ok":true}'), 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('planning: a member books a class; a full class cannot be booked', (tester) async {
    final log = <http.Request>[];
    final today = DateTime.now().weekday - 1;
    await signedIn(athlete);
    Api.client = fakeServer({
      'GET classes': [
        {
          'id': 4,
          'day': today,
          'time': '18:00',
          'title': 'Crossfit',
          'coach_name': 'Sami',
          'coach_id': 2,
          'spots': 10,
          'taken': 2,
          'mine': 0,
        },
        {'id': 5, 'day': today, 'time': '19:00', 'title': 'Yoga', 'coach_id': 3, 'spots': 5, 'taken': 5, 'mine': 0},
      ],
    }, log: log);
    await pumpPage(tester, const PlanningPage());

    expect(find.text('Crossfit'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Complet')).onPressed, isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Réserver'));
    await tester.pumpAndSettle();
    final book = log.firstWhere((r) => r.method == 'POST');
    expect(book.url.path, '/api/book');
    expect(jsonDecode(book.body), {'class_id': 4});
  });

  testWidgets('planning: a coach sees "Vous animez" on the classes they run', (tester) async {
    final today = DateTime.now().weekday - 1;
    await signedIn(coach, {
      'GET classes': [
        {'id': 4, 'day': today, 'time': '18:00', 'title': 'Musculation', 'coach_id': 2, 'spots': 10, 'taken': 2},
      ],
    });
    await pumpPage(tester, const PlanningPage());
    expect(find.text('Vous animez'), findsOneWidget);
  });

  testWidgets('CRUD: admin searches on the server and the form validates', (tester) async {
    final log = <http.Request>[];
    await signedIn(admin);
    Api.client = fakeServer({
      'GET equipment': [
        {'id': 1, 'name': 'Tapis de course', 'category': 'Cardio', 'qty': 6, 'status': 'OK'},
      ],
    }, log: log);
    await pumpPage(tester, CrudPage(moduleById('equipment')));

    expect(find.text('Tapis de course × 6'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'tapis');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(log.any((r) => r.url.queryParameters['q'] == 'tapis'), isTrue);

    await tester.tap(find.text('Ajouter'));
    await tester.pumpAndSettle();
    expect(find.text('Ajouter équipement'), findsOneWidget);
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Obligatoire'), findsOneWidget);
  });

  testWidgets('CRUD: a member has no add button in read-only modules', (tester) async {
    await signedIn(athlete);
    await pumpPage(tester, CrudPage(moduleById('plans')));
    expect(find.text('Ajouter'), findsNothing);
    expect(find.text('Aucun élément'), findsOneWidget);
  });

  testWidgets('member home shows the error with a retry button when the server is down', (tester) async {
    await signedIn(athlete);
    Api.client = MockClient((_) async => http.Response.bytes(utf8.encode('{"error":"Maintenance en cours"}'), 503));
    await pumpPage(tester, MemberHome(goTab: (_) {}));
    expect(find.text('Maintenance en cours'), findsOneWidget);
    expect(find.text('Réessayer'), findsOneWidget);
  });
}
