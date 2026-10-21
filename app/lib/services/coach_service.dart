import '../core/network/api_client.dart';
import 'user_service.dart' show Json;

/// Relations coach ↔ client et tableau de bord du coach.
class CoachService {
  CoachService._();

  /// Mes coachs (vue membre).
  static Future<List<Json>> myCoaches() => Api.list('coaching/mine');

  static Future<void> requestCoach(int coachId) => Api.post('coaching/request', {'coach_id': coachId});

  /// Fin d'un suivi ou annulation d'une demande (coach, client ou admin).
  static Future<void> endLink(int linkId) => Api.post('coaching/$linkId/end');

  /// Demandes en attente + clients actifs (vue coach).
  static Future<List<Json>> clients() => Api.list('coaching/clients');

  static Future<void> answer(int linkId, {required bool accept}) => Api.post('coaching/$linkId/${accept ? 'accept' : 'decline'}');

  /// Statistiques limitées aux clients et aux cours du coach.
  static Future<Json> stats() => Api.get('stats');
}
