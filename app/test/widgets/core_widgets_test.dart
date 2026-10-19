import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/core/theme/app_theme.dart';
import 'package:ironfit/core/widgets/async_view.dart';
import 'package:ironfit/core/widgets/charts.dart';
import 'package:ironfit/core/widgets/empty_state.dart';
import 'package:ironfit/core/widgets/feedback.dart';
import 'package:ironfit/core/widgets/form_dialog.dart';
import 'package:ironfit/core/widgets/kpi.dart';

Future<void> pumpApp(WidgetTester tester, Widget child, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('EmptyState shows its text and calls its action', (tester) async {
    var taps = 0;
    await pumpApp(
      tester,
      Scaffold(
        body: EmptyState(icon: Icons.event, text: 'Rien ici', cta: 'Ajouter', onTap: () => taps++),
      ),
    );
    expect(find.text('Rien ici'), findsOneWidget);
    await tester.tap(find.text('Ajouter'));
    expect(taps, 1);
  });

  testWidgets('KpiCard is announced as a single "label : value" node', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const Scaffold(
        body: KpiGrid(
          children: [KpiCard(icon: Icons.groups, label: 'Membres', value: '12')],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Membres : 12'), findsOneWidget);
    handle.dispose();
  });

  for (final scale in [1.0, 1.5, 2.0]) {
    testWidgets('KPI grids do not overflow at ${scale}x text', (tester) async {
      await pumpApp(
        tester,
        Scaffold(
          body: ListView(
            children: const [
              KpiGrid(
                columns: 3,
                children: [
                  KpiCard(icon: Icons.local_fire_department, label: 'Séances (7 j)', value: '12'),
                  KpiCard(icon: Icons.event_available, label: 'Réservations', value: '3'),
                  KpiCard(icon: Icons.monitor_weight, label: 'Poids', value: '78.5 kg'),
                ],
              ),
              KpiGrid(
                children: [
                  KpiCard(icon: Icons.sports, label: 'Coachs · suivis actifs', value: '3 · 12'),
                  KpiCard(icon: Icons.block, label: 'Comptes désactivés', value: '0'),
                ],
              ),
            ],
          ),
        ),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('charts expose a text summary to screen readers', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      const Scaffold(
        body: Column(
          children: [
            BarChart(labels: ['Sep', 'Oct'], values: [100, 220], semanticsLabel: 'Revenus : Sep 100, Oct 220'),
            LineChart(values: [80, 78], semanticsLabel: 'Poids de 80 à 78'),
          ],
        ),
      ),
    );
    expect(find.bySemanticsLabel('Revenus : Sep 100, Oct 220'), findsOneWidget);
    expect(find.bySemanticsLabel('Poids de 80 à 78'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('StatusMessage is a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, const Scaffold(body: StatusMessage('Identifiants incorrects')));
    expect(tester.getSemantics(find.text('Identifiants incorrects')).flagsCollection.isLiveRegion, isTrue);
    handle.dispose();
  });

  testWidgets('InitialAvatar never throws on empty names', (tester) async {
    await pumpApp(
      tester,
      const Scaffold(body: Row(children: [InitialAvatar(''), InitialAvatar(null), InitialAvatar('sami')])),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('?'), findsNWidgets(2));
    expect(find.text('S'), findsOneWidget);
  });

  testWidgets('AsyncLoadMixin: loading, then error with retry, then data', (tester) async {
    var attempt = 0;
    await pumpApp(
      tester,
      _Loader(() async {
        attempt++;
        if (attempt == 1) throw Exception('Serveur injoignable');
        return 'Bonjour';
      }),
    );
    expect(find.textContaining('Serveur injoignable'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Bonjour'), findsOneWidget);
    expect(attempt, 2);
  });

  testWidgets('confirm() returns true only when confirmed', (tester) async {
    bool? result;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await confirm(context, 'Supprimer ?', ok: 'Supprimer'),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Supprimer'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('formDialog: a future date already in the field does not crash the date picker', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => formDialog(context, 'Mesure', const [
            DField('measured_on', 'Date', type: DType.date, initial: '2099-01-01'),
          ]),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextFormField, 'Date'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('formDialog shows the server error inside the dialog', (tester) async {
    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => formDialog(context, 'Programme', const [
            DField('title', 'Titre', required: true),
          ], submit: (_) async => throw Exception('Refusé par le serveur')),
          child: const Text('go'),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Obligatoire'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'Force');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Refusé par le serveur'), findsOneWidget);
  });
}

class _Loader extends StatefulWidget {
  final Future<String> Function() load;
  const _Loader(this.load);

  @override
  State<_Loader> createState() => _LoaderState();
}

class _LoaderState extends State<_Loader> with AsyncLoadMixin<_Loader, String> {
  @override
  Future<String> fetch() => widget.load();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AsyncStateView(loading: loading, error: error, data: data, onRetry: reload, builder: (_, s) => Text(s)),
  );
}
