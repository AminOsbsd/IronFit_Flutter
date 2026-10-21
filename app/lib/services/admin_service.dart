import '../core/network/api_client.dart';
import 'user_service.dart' show Json;

/// Opérations réservées à l'administration (le serveur refuse toute autre origine).
class AdminService {
  AdminService._();

  static Future<Json> stats() => Api.get('stats');

  static Future<List<Json>> pendingRequests() => Api.list('requests');

  static Future<void> approveRequest(int id, String method) => Api.post('requests/$id/approve', {'method': method});

  static Future<void> rejectRequest(int id) => Api.post('requests/$id/reject');

  static Future<void> renew(int memberId, {required Object? planId, required String method}) =>
      Api.post('members/$memberId/renew', {'plan_id': planId, 'method': method});

  static Future<void> setAccountActive(int memberId, bool active) => Api.post('members/$memberId/status', {'active': active});

  static Future<List<Json>> members({String? role, String? q, int limit = 500}) => Api.list(Api.withQuery('members', {'role': role, 'q': q, 'limit': limit}));

  static Future<List<Json>> coachingLinks({String? status}) => Api.list(Api.withQuery('coaching', {'status': status}));

  static Future<void> assignCoach(Object? coachId, Object? clientId) => Api.post('coaching/assign', {'coach_id': coachId, 'client_id': clientId});

  static Future<void> endCoaching(int linkId) => Api.post('coaching/$linkId/end');
}
