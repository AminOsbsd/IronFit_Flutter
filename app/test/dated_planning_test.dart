import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/screens/planning_screen.dart';
import 'helpers.dart';

void main() {
  testWidgets('next week fetches explicit dated schedule', (tester) async {
    await signedIn(athlete);
    final log = <http.Request>[];
    Api.client = fakeServer({}, log: log);
    useScreen(tester);
    await tester.pumpWidget(const MaterialApp(home: PlanningPage()));
    await tester.pumpAndSettle();
    final before = log.last.url.queryParameters['week'];
    expect(before, isNotNull);
    await tester.tap(find.byTooltip('Semaine suivante'));
    await tester.pumpAndSettle();
    final after = log.last.url.queryParameters['week'];
    expect(
      DateTime.parse(after!).difference(DateTime.parse(before!)).inDays,
      7,
    );
    expect(tester.takeException(), isNull);
  });
}
