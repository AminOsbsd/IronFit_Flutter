import 'package:flutter/foundation.dart';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/coach_message.dart';
import 'ai_coach_service.dart';

/// État de la conversation AI Coach.
enum CoachStatus {
  /// Prêt à recevoir un message.
  idle,
  /// Message envoyé, en attente du premier morceau de réponse (indicateur « écrit… »).
  waiting,
  /// Réponse en cours de réception.
  streaming,
  /// La dernière demande a échoué (voir [AiCoachChat.error]).
  failed,
}

/// Conversation AI Coach de la session : conservée quand le panneau est fermé, effacée à la déconnexion.
class AiCoachChat extends ChangeNotifier {
  /// Conversation partagée par l'application (une seule session utilisateur à la fois).
  static final AiCoachChat instance = AiCoachChat();

  /// Source des réponses (remplaçable dans les tests).
  Stream<String> Function(List<CoachMessage> history, String workspace) source =
      (history, workspace) => AiCoachService.reply(history, workspace: workspace);

  final List<CoachMessage> _messages = [];
  CoachStatus status = CoachStatus.idle;
  String? error;
  /// Incrémenté à chaque effacement / arrêt : une réponse en cours d'une ancienne génération est ignorée.
  int _generation = 0;

  AiCoachChat() {
    Api.authChanged.addListener(clear); // déconnexion ou changement de compte : rien ne reste en mémoire
  }

  List<CoachMessage> get messages => List.unmodifiable(_messages);
  bool get busy => status == CoachStatus.waiting || status == CoachStatus.streaming;
  bool get isEmpty => _messages.isEmpty;

  /// Envoie un message ; ignoré s'il est vide ou si une réponse est déjà en cours.
  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || busy) return;
    if (t.length > AppConfig.aiCoachMaxChars) {
      status = CoachStatus.failed;
      error = 'Message trop long (${AppConfig.aiCoachMaxChars} caractères max.).';
      notifyListeners();
      return;
    }
    _messages.add(CoachMessage.user(t));
    await _ask();
  }

  /// Relance la dernière question après une erreur (la réponse partielle éventuelle est retirée).
  Future<void> retry() async {
    if (busy || _messages.isEmpty) return;
    if (!_messages.last.isUser) _messages.removeLast();
    if (_messages.isEmpty || !_messages.last.isUser) return;
    await _ask();
  }

  /// Arrête la réponse en cours en gardant le texte déjà reçu.
  void stop() {
    if (!busy) return;
    _generation++;
    status = CoachStatus.idle;
    notifyListeners();
  }

  /// Efface la conversation (et abandonne une réponse en cours).
  void clear() {
    _generation++;
    _messages.clear();
    status = CoachStatus.idle;
    error = null;
    notifyListeners();
  }

  /// Historique envoyé au serveur : les derniers messages non vides, dans les limites acceptées par l'API.
  List<CoachMessage> history() {
    final list = _messages.where((m) => m.content.trim().isNotEmpty).toList();
    final recent = list.length > AppConfig.aiCoachMaxHistory ? list.sublist(list.length - AppConfig.aiCoachMaxHistory) : list;
    return [
      for (final m in recent) m.content.length > 8000 ? CoachMessage(m.role, m.content.substring(0, 8000)) : m,
    ];
  }

  Future<void> _ask() async {
    final gen = ++_generation;
    status = CoachStatus.waiting;
    error = null;
    notifyListeners();
    try {
      await for (final delta in source(history(), Api.inCoachSpace ? 'coach' : 'personal')) {
        if (gen != _generation) return; // effacé ou arrêté entre-temps
        if (status == CoachStatus.waiting) {
          _messages.add(const CoachMessage.assistant(''));
          status = CoachStatus.streaming;
        }
        _messages[_messages.length - 1] = _messages.last.append(delta);
        notifyListeners();
      }
      if (gen != _generation) return;
      if (status == CoachStatus.waiting) {
        // Flux terminé sans texte
        status = CoachStatus.failed;
        error = 'AI Coach n\'a pas répondu. Réessayez.';
      } else {
        status = CoachStatus.idle;
      }
    } catch (e) {
      if (gen != _generation) return;
      status = CoachStatus.failed;
      error = e is ApiException ? e.message : 'Une erreur est survenue. Réessayez.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    Api.authChanged.removeListener(clear);
    super.dispose();
  }
}
