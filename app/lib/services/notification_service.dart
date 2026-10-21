import '../core/network/api_client.dart';
import 'user_service.dart' show Json;

/// Notifications de l'utilisateur connecté.
class NotificationService {
  NotificationService._();

  /// Renvoie les notifications et met à jour le compteur de non lues.
  static Future<List<Json>> load({int limit = 100}) async {
    final r = await Api.get(Api.withQuery('notifications', {'limit': limit}));
    Api.unread.value = (r['unread'] as num? ?? 0).toInt();
    return (r['items'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> markRead(int id) async {
    await Api.post('notifications/$id/read');
    Api.unread.value = (Api.unread.value - 1).clamp(0, 1 << 30);
  }

  static Future<void> markAllRead() async {
    await Api.post('notifications/read-all');
    Api.unread.value = 0;
  }

  /// Met à jour la pastille (silencieux en cas d'erreur).
  static Future<void> refreshUnread() async {
    try {
      Api.unread.value = ((await Api.get(Api.withQuery('notifications', {'limit': 1})))['unread'] as num? ?? 0).toInt();
    } catch (_) {}
  }
}
