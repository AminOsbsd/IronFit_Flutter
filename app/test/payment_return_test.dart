import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/screens/stripe_payments_screen.dart';
import 'helpers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/main.dart';

void main() {
  test('Stripe return identifies the order, never a paid status', () {
    expect(
      paymentReturnOrder(
        Uri.parse(
          'http://localhost:5173/?payment_order=8-eur-abc&payment_return=success',
        ),
      ),
      '8-eur-abc',
    );
    expect(
      paymentReturnOrder(
        Uri.parse('http://localhost:5173/?payment_return=success'),
      ),
      isNull,
    );
    expect(
      paymentReturnOrder(
        Uri.parse('http://localhost:5173/?payment_order=../other'),
      ),
      isNull,
    );
  });
  testWidgets(
    'return automatically reconciles pending checkout and shows confirmation',
    (tester) async {
      await signedIn(athlete);
      useScreen(tester);
      var reconciled = false;
      var calls = 0;
      Api.client = MockClient((request) async {
        Object body;
        if (request.url.path.endsWith('/reconcile')) {
          reconciled = true;
          calls++;
          body = {'status': 'paid'};
        } else if (request.url.path.endsWith('/history')) {
          body = [];
        } else if (request.url.path.endsWith('/me')) {
          body = athlete;
        } else {
          body = {
            'status': reconciled ? 'paid' : 'pending',
            'checkout_status': 'complete',
            'plan': 'Mensuel',
            'amount': 60,
            'currency': 'EUR',
            'mode': 'payment',
          };
        }
        return http.Response(
          jsonEncode(body),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      await tester.pumpWidget(
        const MaterialApp(home: StripePaymentsPage(orderId: '4-eur-return')),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Paiement confirmé'), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
