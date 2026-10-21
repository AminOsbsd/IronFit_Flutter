import '../core/network/api_client.dart';
import 'user_service.dart' show Json;

/// Programmes, exercices, séances réalisées et commentaires du coach.
class ProgramService {
  ProgramService._();

  /// scope : personal (mes programmes) ou coaching (programmes écrits pour un client).
  static Future<List<Json>> programs({required String scope, int? clientId}) =>
      Api.list(Api.withQuery('programs', {'scope': scope, 'client_id': clientId}));

  static Future<Json> program(int id) => Api.get('programs/$id');

  /// [clientId] null = programme personnel.
  static Future<int> create(Json values, {int? clientId}) async =>
      ((await Api.post('programs', {...values, 'client_id': clientId}))['id'] as num).toInt();

  static Future<void> update(int id, Json values) => Api.put('programs/$id', values);

  static Future<void> delete(int id) => Api.delete('programs/$id');

  static Future<void> addExercise(int programId, Json values) => Api.post('programs/$programId/exercises', values);

  static Future<void> updateExercise(int id, Json values) => Api.put('exercises/$id', values);

  static Future<void> deleteExercise(int id) => Api.delete('exercises/$id');

  /// [userId] null = mes séances.
  static Future<List<Json>> workouts({int? userId, int? programId, int limit = 100}) =>
      Api.list(Api.withQuery('workouts', {'user_id': userId, 'program_id': programId, 'limit': limit}));

  static Future<void> logWorkout(Json values, {int? programId}) => Api.post('workouts', {...values, 'program_id': programId});

  static Future<void> deleteWorkout(int id) => Api.delete('workouts/$id');

  static Future<void> comment(int workoutId, String? comment) => Api.post('workouts/$workoutId/feedback', {'comment': comment});
}
