import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/screens/launch_splash.dart';

Widget host(
  Future<void> Function() initialize, {
  bool reduced = false,
  String label = 'Destination',
}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: LaunchSplash(
      initialize: initialize,
      destination: (_) => Scaffold(body: Text(label)),
    ),
  ),
);

void main() {
  testWidgets(
    'ready app completes a short introduction and never replays on rebuild',
    (tester) async {
      var starts = 0;
      Future<void> initialize() async {
        starts++;
      }

      await tester.pumpWidget(host(initialize));
      await tester.pump();
      expect(find.byKey(const ValueKey('launch-splash')), findsOneWidget);
      expect(find.text('Destination'), findsNothing);
      await tester.pump(const Duration(milliseconds: 2100));
      await tester.pumpAndSettle();
      expect(find.text('Destination'), findsOneWidget);
      expect(find.byKey(const ValueKey('launch-splash')), findsNothing);
      await tester.pumpWidget(host(initialize, label: 'Another session'));
      await tester.pumpAndSettle();
      expect(starts, 1);
      expect(find.text('Another session'), findsOneWidget);
      expect(find.byKey(const ValueKey('launch-splash')), findsNothing);
    },
  );

  testWidgets('slow initialization holds the logo and transitions when ready', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(host(() => ready.future));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Préparation de votre espace…'), findsOneWidget);
    expect(find.text('Destination'), findsNothing);
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('Destination'), findsOneWidget);
  });

  testWidgets('reduced motion removes animation and the minimum delay', (
    tester,
  ) async {
    await tester.pumpWidget(host(() async {}, reduced: true));
    await tester.pump();
    expect(find.text('Destination'), findsOneWidget);
    expect(find.byKey(const ValueKey('launch-splash')), findsNothing);
  });

  testWidgets('initialization failures are retryable', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      host(() async {
        if (++attempts == 1) throw StateError('storage unavailable');
      }, reduced: true),
    );
    await tester.pump();
    expect(find.text('Réessayer'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Destination'), findsOneWidget);
    expect(attempts, 2);
  });

  for (final size in [
    const Size(320, 568),
    const Size(1440, 900),
    const Size(568, 320),
  ]) {
    testWidgets('responsive splash fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final ready = Completer<void>();
      await tester.pumpWidget(host(() => ready.future));
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      ready.complete();
      await tester.pumpAndSettle();
    });
  }
}
