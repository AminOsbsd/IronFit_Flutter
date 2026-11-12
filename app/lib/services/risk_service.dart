import '../core/network/api_client.dart';
import 'user_service.dart' show Json;

/// Membres à risque d'abandon : le score est calculé par le serveur (GET /api/risk).
class RiskService {
  RiskService._();

  /// Admin : tous les membres ; coach : ses clients actifs. Du plus risqué au moins risqué.
  /// [all] inclut aussi les membres à risque faible.
  static Future<List<Json>> atRisk({bool all = false}) => Api.list(all ? 'risk?all=true' : 'risk');

  /// Relance un membre : notification dans l'application + e-mail envoyé tout de suite.
  /// Renvoie {ok, email_sent, email_info} : email_info donne la raison quand l'e-mail n'est pas parti.
  static Future<Json> remind(int memberId) => Api.post('risk/$memberId/remind');

  /// Admin : lance l'analyse automatique tout de suite ; renvoie le nombre de relances envoyées.
  static Future<int> runNow() async => ((await Api.post('risk/run'))['alerts'] as num).toInt();
}
