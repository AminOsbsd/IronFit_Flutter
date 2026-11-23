import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/screens/planning_screen.dart';
import 'helpers.dart';

void main() {
  testWidgets('member sees confirmed attendance for a booked session', (tester) async {
    await signedIn(athlete, {'GET classes': [
      {'id': 1, 'day': DateTime.now().weekday-1, 'time':'00:00', 'title':'Strength',
       'coach_name':'Sami', 'spots':10, 'taken':1, 'mine':true, 'attendance_status':'present'}
    ]});
    useScreen(tester, width:360);
    await tester.pumpWidget(const MaterialApp(home:PlanningPage()));
    await tester.pumpAndSettle();
    expect(find.text('Présence confirmée'), findsOneWidget);
    expect(find.text('Annuler'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('coach can correct past attendance to absent', (tester) async {
    await signedIn(coach);
    final log=<http.Request>[];
    Api.client=fakeServer({'GET classes/1/participants': [
      {'id':4,'name':'Youssef','present':true,'attendance_status':'present'}
    ]}, log:log);
    useScreen(tester);
    await tester.pumpWidget(const MaterialApp(home:ParticipantsPage(
      {'id':1,'title':'Strength','time':'18:00','session_date':'2020-01-06','day':0})));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Présent ▾'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Absent'));
    await tester.pumpAndSettle();
    final sent=log.where((r)=>r.method=='POST').single;
    expect(sent.body,contains('"attendance_status":"absent"'));
    expect(sent.body,contains('2020-01-06'));
    expect(tester.takeException(),isNull);
  });
}
