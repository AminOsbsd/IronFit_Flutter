import '../core/network/api_client.dart';
import 'user_service.dart' show Json;

/// Planning hebdomadaire, réservations, participants et pointage.
class PlanningService {
  PlanningService._();

  static Future<List<Json>> classes() => Api.list('classes');

  /// Réserve ou annule (bascule) ; renvoie true si le cours est maintenant réservé.
  static Future<bool> toggleBooking(int classId) async => (await Api.post('book', {'class_id': classId}))['booked'] == true;

  static Future<List<Json>> participants(int classId) => Api.list('classes/$classId/participants');

  static Future<void> markPresent(int classId, int memberId) => Api.post('classes/$classId/present', {'member_id': memberId});
}
