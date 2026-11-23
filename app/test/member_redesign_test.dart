import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/main.dart';
import 'package:ironfit/core/theme/app_theme.dart';
import 'package:ironfit/screens/planning_screen.dart';
import 'package:ironfit/screens/program_screens.dart';
import 'package:ironfit/widgets/member_design.dart';
import 'helpers.dart';

void main() {
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_UI') &&
        const String.fromEnvironment('PREVIEW_FONT').isNotEmpty &&
        const String.fromEnvironment('PREVIEW_ICONS').isNotEmpty) {
      final text = FontLoader('Roboto')
        ..addFont(
          File(
            const String.fromEnvironment('PREVIEW_FONT'),
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          File(
            const String.fromEnvironment('PREVIEW_ICONS'),
          ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
        );
      await text.load();
      await icons.load();
    }
  });
  for (final width in [320.0, 420.0, 1300.0]) {
    testWidgets('member destinations fit width $width', (tester) async {
      await signedIn(athlete);
      useScreen(tester, width: width, height: width == 320 ? 568 : 900);
      await tester.pumpWidget(const IronFitApp());
      await tester.pumpAndSettle();
      for (final tab in [
        'Accueil',
        'Planning',
        'Explorer',
        'Mon espace',
        'Profil',
      ]) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab at $width');
        if (const bool.fromEnvironment('CAPTURE_UI') && width == 420) {
          await tester.runAsync(() async {
            await precacheImage(
              const AssetImage('assets/images/member_fitness_3d.png'),
              tester.element(find.byType(MaterialApp)),
            );
          });
          await tester.pumpAndSettle();
          await expectLater(
            find.byType(IronFitApp),
            matchesGoldenFile(
              '../build/ui-review/member-${tab.replaceAll(' ', '-')}.png',
            ),
          );
        }
      }
    });
  }
  testWidgets('reservations use dates and coach attendance, not mock statuses', (
    tester,
  ) async {
    final day = DateTime.now();
    final date =
        '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    await signedIn(athlete, {
      'GET classes': [
        {
          'id': 1,
          'day': day.weekday - 1,
          'session_date': date,
          'time': '23:59',
          'title': 'Future class',
          'mine': true,
          'spots': 10,
          'taken': 1,
          'attendance_status': 'pending',
        },
        {
          'id': 2,
          'day': day.weekday - 1,
          'session_date': date,
          'time': '00:00',
          'title': 'Completed class',
          'mine': true,
          'spots': 10,
          'taken': 1,
          'attendance_status': 'present',
        },
      ],
    });
    useScreen(tester, width: 420);
    await tester.pumpWidget(
      MaterialApp(
        theme: memberTheme(AppTheme.light()),
        home: const PlanningPage(reservationsOnly: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Future class'), findsOneWidget);
    expect(find.text('Completed class'), findsNothing);
    await tester.tap(find.text('Passées'));
    await tester.pumpAndSettle();
    expect(find.text('Completed class'), findsOneWidget);
    expect(find.text('Votre présence a été confirmée !'), findsOneWidget);
    if (const bool.fromEnvironment('CAPTURE_UI')) {
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../build/ui-review/member-reservations.png'),
      );
    }
    await tester.tap(find.text('Annulées'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ne sont pas conservées'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('program empty state keeps create action and accessible text', (
    tester,
  ) async {
    await signedIn(athlete);
    useScreen(tester, width: 320, height: 568);
    await tester.pumpWidget(
      MaterialApp(
        theme: memberTheme(AppTheme.light()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(1.5),
            disableAnimations: true,
          ),
          child: child!,
        ),
        home: const ProgramsPage(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Nouveau programme'), 160);
    expect(find.text('Nouveau programme'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Créer mon programme'), 180);
    expect(tester.takeException(), isNull);
  });
  testWidgets('weekly reservations sort by date before time', (tester) async {
    final now = DateTime.now();
    String date(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    await signedIn(athlete, {
      'GET classes': [
        {
          'id': 1,
          'day': 1,
          'session_date': date(now.add(const Duration(days: 2))),
          'time': '08:00',
          'title': 'Later booking',
          'mine': true,
        },
        {
          'id': 2,
          'day': 0,
          'session_date': date(now.add(const Duration(days: 1))),
          'time': '19:00',
          'title': 'Earlier booking',
          'mine': true,
        },
      ],
    });
    useScreen(tester, width: 420, height: 1400);
    await tester.pumpWidget(
      MaterialApp(
        theme: memberTheme(AppTheme.light()),
        home: const PlanningPage(reservationsOnly: true),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Earlier booking')).dy,
      lessThan(tester.getTopLeft(find.text('Later booking')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}
