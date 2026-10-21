import '../core/network/api_client.dart';

typedef Json = Map<String, dynamic>;

/// Données du membre connecté (ou d'un client pour son coach) : mesures, présences, abonnement, annuaire des coachs.
class UserService {
  UserService._();

  static Future<List<Json>> measures(int memberId) => Api.list(Api.withQuery('measures', {'member_id': memberId}));

  static Future<void> addMeasure(int memberId, Json values) => Api.post('measures', {...values, 'member_id': memberId});

  static Future<List<Json>> checkins(int memberId) => Api.list(Api.withQuery('checkins', {'member_id': memberId}));

  static Future<List<Json>> myRequests() => Api.list('requests');

  static Future<void> requestPlan(int planId) => Api.post('requests', {'plan_id': planId});

  static Future<void> cancelRequest(int id) => Api.post('requests/$id/cancel');

  /// Annuaire des coachs (sans données de contact).
  static Future<List<Json>> coaches() => Api.list('coaches');
}
