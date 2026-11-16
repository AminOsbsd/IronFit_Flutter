import 'dart:convert';
import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../models/coach_message.dart';

/// AI Coach : le serveur IronFit relaie la conversation vers OpenRouter (la clé reste sur le serveur).
class AiCoachService {
  AiCoachService._();

  /// true si le serveur a une clé OpenRouter configurée.
  static Future<bool> enabled() async => (await Api.get('ai-coach/status'))['enabled'] == true;

  /// Envoie l'historique et renvoie la réponse du coach morceau par morceau.
  /// [workspace] : « coach » quand un coach est dans son espace professionnel, sinon « personal ».
  static Stream<String> reply(List<CoachMessage> history, {String workspace = 'personal'}) async* {
    final chunks = await Api.postStream(
      'ai-coach/chat',
      {'messages': [for (final m in history) m.toJson()], 'workspace': workspace},
      timeout: AppConfig.aiCoachTimeout,
      idle: AppConfig.aiCoachIdleTimeout,
    );
    yield* deltas(chunks);
  }

  /// Lit le flux SSE du serveur : `data: {"delta": "…"}`, puis `data: {"done": true}` ou `data: {"error": "…"}`.
  /// Un flux qui se termine sans « done » est considéré comme interrompu.
  static Stream<String> deltas(Stream<String> chunks) async* {
    var buffer = '';
    await for (final chunk in chunks) {
      buffer += chunk.replaceAll('\r\n', '\n');
      var end = buffer.indexOf('\n\n');
      while (end >= 0) {
        final event = buffer.substring(0, end);
        buffer = buffer.substring(end + 2);
        for (final line in event.split('\n')) {
          if (!line.startsWith('data:')) continue;
          final Object? data;
          try {
            data = jsonDecode(line.substring(5).trim());
          } catch (_) {
            continue;
          }
          if (data is! Map) continue;
          if (data['error'] != null) throw ApiException('${data['error']}');
          if (data['done'] == true) return;
          final delta = data['delta'];
          if (delta is String && delta.isNotEmpty) yield delta;
        }
        end = buffer.indexOf('\n\n');
      }
    }
    throw ApiException('La réponse d\'AI Coach a été interrompue. Réessayez.');
  }
}
