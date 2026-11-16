import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ironfit/core/network/api_client.dart';
import 'package:ironfit/main.dart';
import 'package:ironfit/models/coach_message.dart';
import 'package:ironfit/services/ai_coach_chat.dart';
import 'package:ironfit/services/ai_coach_service.dart';
import 'package:ironfit/widgets/ai_coach.dart';
import 'helpers.dart';

/// Réponse du serveur IronFit en flux SSE (le serveur relaie OpenRouter, simulé ici).
http.Response sse(List<String> parts, {bool done = true, String? error}) {
  final b = StringBuffer();
  for (final p in parts) {
    b.write('data: ${jsonEncode({'delta': p})}\n\n');
  }
  if (error != null) b.write('data: ${jsonEncode({'error': error})}\n\n');
  if (done) b.write('data: {"done":true}\n\n');
  return http.Response.bytes(utf8.encode(b.toString()), 200, headers: {'content-type': 'text/event-stream'});
}

http.Response jsonError(int status, String message) =>
    http.Response.bytes(utf8.encode(jsonEncode({'error': message, 'status': status})), status, headers: {'content-type': 'application/json'});

void main() {
  setUp(() => AiCoachChat.instance
    ..source = ((h, w) => AiCoachService.reply(h, workspace: w))
    ..clear());

  group('lecture du flux SSE', () {
    test('morceaux coupés au milieu d\'un événement, fins de ligne CRLF, arrêt sur « done »', () async {
      final chunks = Stream.fromIterable(['data: {"delta":"Bon', 'jour"}\r\n\r\n: commentaire\n\ndata: {"delta":" Youssef"}\n', '\ndata: {"done":true}\n\ndata: {"delta":"ignoré"}\n\n']);
      expect(await AiCoachService.deltas(chunks).toList(), ['Bonjour', ' Youssef']);
    });

    test('un événement « error » ou un flux coupé sans « done » lèvent une erreur lisible', () async {
      await expectLater(
        AiCoachService.deltas(Stream.value('data: {"delta":"a"}\n\ndata: {"error":"Réponse trop longue"}\n\n')).toList(),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Réponse trop longue')),
      );
      await expectLater(AiCoachService.deltas(Stream.value('data: {"delta":"a"}\n\n')).toList(), throwsA(isA<ApiException>()));
    });
  });

  group('appel du serveur', () {
    test('l\'historique, l\'espace et le jeton sont envoyés ; jamais de clé OpenRouter côté application', () async {
      final log = <http.Request>[];
      await signedIn(coach);
      Api.client = fakeServer({'POST ai-coach/chat': sse(['Salut', ' coach'])}, log: log);
      final out = await AiCoachService.reply(const [CoachMessage.user('Bonjour')], workspace: 'coach').toList();
      expect(out.join(), 'Salut coach');
      final req = log.single;
      expect(req.url.path, '/api/ai-coach/chat');
      expect(req.headers['Authorization'], 'Bearer jeton');
      expect(req.headers['Accept'], allOf(contains('text/event-stream'), contains('application/json')), reason: 'les erreurs arrivent en JSON');
      expect(jsonDecode(req.body), {
        'messages': [
          {'role': 'user', 'content': 'Bonjour'},
        ],
        'workspace': 'coach',
      });
      expect(req.body.toLowerCase(), isNot(contains('openrouter')));
    });

    test('une erreur du serveur (ex. 429) remonte avec son message sans déconnecter', () async {
      await signedIn(athlete, {'POST ai-coach/chat': jsonError(429, 'AI Coach est très sollicité. Réessayez dans un instant.')});
      await expectLater(
        AiCoachService.reply(const [CoachMessage.user('x')]).toList(),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 429).having((e) => e.message, 'message', contains('sollicité'))),
      );
      expect(Api.user, isNotNull, reason: 'une erreur d\'IA ne déconnecte pas');
    });
  });

  group('conversation (état)', () {
    test('envoi → attente → streaming → prêt ; erreur → réessayer ; effacer', () async {
      await signedIn(athlete);
      final chat = AiCoachChat.instance;
      final statuses = <CoachStatus>[];
      chat.addListener(() => statuses.add(chat.status));
      var fail = true;
      chat.source = (history, workspace) async* {
        expect(workspace, 'personal');
        expect(history.last.content, 'Que faire aujourd\'hui ?');
        if (fail) {
          fail = false;
          throw ApiException('AI Coach met trop de temps à répondre. Réessayez.', 504);
        }
        yield 'Séance ';
        yield 'légère.';
      };

      await chat.send('   ');
      expect(chat.isEmpty, isTrue, reason: 'message vide ignoré');

      await chat.send(' Que faire aujourd\'hui ? ');
      expect(chat.status, CoachStatus.failed);
      expect(chat.error, contains('trop de temps'));
      expect(chat.messages.single.content, 'Que faire aujourd\'hui ?');

      await chat.retry();
      expect(chat.status, CoachStatus.idle);
      expect(chat.messages.map((m) => m.content), ['Que faire aujourd\'hui ?', 'Séance légère.']);
      expect(statuses, containsAllInOrder([CoachStatus.waiting, CoachStatus.failed, CoachStatus.waiting, CoachStatus.streaming, CoachStatus.idle]));

      chat.clear();
      expect(chat.isEmpty && chat.error == null && chat.status == CoachStatus.idle, isTrue);
    });

    test('effacer pendant une réponse l\'abandonne ; un message trop long est refusé ; la déconnexion efface tout', () async {
      await signedIn(athlete);
      final chat = AiCoachChat.instance;
      final gate = Completer<void>();
      chat.source = (_, _) async* {
        yield 'Début';
        await gate.future;
        yield ' fin';
      };
      final pending = chat.send('Salut');
      await Future<void>.delayed(Duration.zero);
      expect(chat.status, CoachStatus.streaming);
      chat.clear();
      gate.complete();
      await pending;
      expect(chat.isEmpty, isTrue);

      await chat.send('x' * 2001);
      expect(chat.status, CoachStatus.failed);
      expect(chat.isEmpty, isTrue);

      chat.source = (_, _) => Stream.value('ok');
      await chat.send('Salut');
      expect(chat.messages, hasLength(2));
      await Api.logout();
      expect(chat.isEmpty, isTrue);
    });

    test('seuls les 20 derniers messages sont envoyés', () async {
      await signedIn(athlete);
      final chat = AiCoachChat.instance;
      chat.source = (_, _) => Stream.value('ok');
      for (var i = 0; i < 12; i++) {
        await chat.send('Question $i');
      }
      final h = chat.history();
      expect(h, hasLength(20));
      expect(h.last.content, 'ok');
    });
  });

  group('interface', () {
    Future<void> open(WidgetTester tester, {double width = 420}) async {
      useScreen(tester, width: width);
      await tester.pumpWidget(const IronFitApp());
      await tester.pumpAndSettle();
    }

    testWidgets('le bouton AI Coach est sur tous les onglets ; le chat répond en streaming et au clavier', (tester) async {
      await signedIn(athlete, {
        'GET ai-coach/status': {'enabled': true, 'model': 'test/model'},
        'POST ai-coach/chat': sse(['Bravo Youssef, ', 'continue comme ça !']),
      });
      await open(tester);

      for (final tab in ['Planning', 'Explorer', 'Mon espace', 'Profil', 'Accueil']) {
        await tester.tap(find.text(tab).last);
        await tester.pumpAndSettle();
        expect(find.byTooltip('AI Coach'), findsOneWidget, reason: 'onglet $tab');
      }

      await tester.tap(find.byTooltip('AI Coach'));
      await tester.pumpAndSettle();
      expect(find.byType(AiCoachPanel), findsOneWidget);
      expect(find.text('Bonjour Youssef !'), findsOneWidget); // état vide avec suggestions
      expect(find.text('Analyse mes dernières séances'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Comment progresser ?');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); // Entrée envoie
      await tester.pumpAndSettle();
      expect(find.text('Comment progresser ?'), findsOneWidget);
      expect(find.text('Bravo Youssef, continue comme ça !'), findsOneWidget);
      expect(AiCoachChat.instance.messages, hasLength(2));

      // Fermer puis rouvrir : l'historique de la session est conservé
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(AiCoachPanel), findsNothing);
      await tester.tap(find.byTooltip('AI Coach'));
      await tester.pumpAndSettle();
      expect(find.text('Bravo Youssef, continue comme ça !'), findsOneWidget);

      await tester.tap(find.byTooltip('Effacer la conversation'));
      await tester.pumpAndSettle();
      expect(find.text('Analyse mes dernières séances'), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.byType(AiCoachPanel), findsNothing);
    });

    testWidgets('une erreur du serveur s\'affiche avec « Réessayer »', (tester) async {
      await signedIn(athlete, {'POST ai-coach/chat': jsonError(503, 'AI Coach n\'est pas configuré sur le serveur (clé OpenRouter manquante).')});
      await open(tester);
      await tester.tap(find.byTooltip('AI Coach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Que faire à ma prochaine séance ?'));
      await tester.pumpAndSettle();
      expect(find.textContaining('pas configuré'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('sans clé côté serveur : bandeau explicatif et saisie désactivée', (tester) async {
      await signedIn(athlete, {'GET ai-coach/status': {'enabled': false, 'model': 'x'}});
      await open(tester);
      await tester.tap(find.byTooltip('AI Coach'));
      await tester.pumpAndSettle();
      expect(find.textContaining('OPENROUTER_API_KEY'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('grand écran : bouton avec libellé et panneau latéral ; coach dans son espace', (tester) async {
      final log = <http.Request>[];
      await signedIn(coach);
      Api.client = fakeServer({
        'GET me': coach,
        'GET stats': <String, Object?>{},
        'GET notifications': {'unread': 0, 'items': []},
        'GET ai-coach/status': {'enabled': true},
        'POST ai-coach/chat': sse(['Voici un programme.']),
      }, log: log);
      await Api.setWorkspace(Workspace.coach);
      await open(tester, width: 1300);
      expect(find.widgetWithText(FloatingActionButton, 'AI Coach'), findsOneWidget);
      await tester.tap(find.text('AI Coach'));
      await tester.pumpAndSettle();
      expect(find.byType(AiCoachPanel), findsOneWidget);
      expect(find.text('Programme de 4 semaines pour un débutant'), findsOneWidget);
      await tester.tap(find.text('Programme de 4 semaines pour un débutant'));
      await tester.pumpAndSettle();
      expect(find.text('Voici un programme.'), findsOneWidget);
      expect(jsonDecode(log.lastWhere((r) => r.url.path.endsWith('ai-coach/chat')).body)['workspace'], 'coach');
      expect(tester.takeException(), isNull);
    });
  });
}
