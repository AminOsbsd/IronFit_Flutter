import '../core/network/api_client.dart';
import 'user_service.dart' show Json;

/// Planning hebdomadaire, réservations, participants et pointage.
class PlanningService {
  PlanningService._();

  static Future<List<Json>> classes({String? week}) =>
      Api.list(week == null ? 'classes' : 'classes?week=$week');

  /// Réserve ou annule (bascule) ; renvoie true si le cours est maintenant réservé.
  static Future<bool> toggleBooking(
    int classId, {
    String? date,
    bool? booked,
  }) async =>
      (await Api.post('book', {
        'class_id': classId,
        if (date != null) 'session_date': date,
        if (booked != null) 'booked': booked,
      }))['booked'] ==
      true;

  static Future<List<Json>> participants(int classId, {String? date}) =>
      Api.list(
        'classes/$classId/participants${date == null ? '' : '?date=$date'}',
      );

  static Future<void> markPresent(
    int classId,
    int memberId, {
    String? date,
    String status = 'present',
  }) => Api.post('classes/$classId/present', {
    'member_id': memberId,
    'attendance_status': status,
    if (date != null) 'session_date': date,
  });
}
