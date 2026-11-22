import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/screens/planning_screen.dart';
import 'helpers.dart';

void main() {
  testWidgets('search and booking filter can be cleared on a narrow screen', (
    tester,
  ) async {
    await signedIn(athlete, {
      'GET classes': [
        {
          'id': 1,
          'day': DateTime.now().weekday - 1,
          'time': '18:00',
          'title': 'Strength',
          'coach_name': 'Sami',
          'spots': 10,
          'taken': 1,
          'mine': true,
        },
        {
          'id': 2,
          'day': DateTime.now().weekday - 1,
          'time': '19:00',
          'title': 'Yoga',
          'coach_name': 'Amira',
          'spots': 10,
          'taken': 0,
          'mine': false,
        },
      ],
    });
    useScreen(tester, width: 360, height: 900);
    await tester.pumpWidget(const MaterialApp(home: PlanningPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mes réservations'));
    await tester.pumpAndSettle();
    expect(find.text('Strength'), findsOneWidget);
    expect(find.text('Yoga'), findsNothing);
    await tester.enterText(find.byType(TextFormField), 'missing');
    await tester.pumpAndSettle();
    expect(
      find.text('Aucun cours ne correspond à vos filtres.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Effacer les filtres'));
    await tester.pumpAndSettle();
    expect(find.text('Yoga'), findsOneWidget);
    expect(find.text('Strength'), findsOneWidget);
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
