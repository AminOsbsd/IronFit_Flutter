/// Message de la conversation avec AI Coach (gardé en mémoire pour la session en cours uniquement).
class CoachMessage {
  /// « user » ou « assistant » (format attendu par POST /api/ai-coach/chat).
  final String role;
  final String content;

  const CoachMessage(this.role, this.content);
  const CoachMessage.user(this.content) : role = 'user';
  const CoachMessage.assistant(this.content) : role = 'assistant';

  bool get isUser => role == 'user';

  CoachMessage append(String delta) => CoachMessage(role, content + delta);

  Map<String, String> toJson() => {'role': role, 'content': content};
}
