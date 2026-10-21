import '../core/network/api_client.dart';
import 'user_service.dart' show Json;

/// Données consultables par tous : tarifs, offres, boutique, annonces.
class CatalogService {
  CatalogService._();

  static Future<List<Json>> plans() => Api.list('plans');
  static Future<List<Json>> promos() => Api.list('promos');
  static Future<List<Json>> products() => Api.list('products');
  static Future<List<Json>> announcements() => Api.list('announcements');
}

/// Accès générique aux ressources gérées par les écrans CRUD (modules déclarés dans models/module.dart).
class CrudService {
  CrudService._();

  static Future<List<Json>> list(String endpoint, Map<String, Object?> query) => Api.list(Api.withQuery(endpoint, query));
  static Future<void> create(String endpoint, Json values) => Api.post(endpoint, values);
  static Future<void> update(String endpoint, Object id, Json values) => Api.put('$endpoint/$id', values);
  static Future<void> delete(String endpoint, Object id) => Api.delete('$endpoint/$id');

  /// Liste qui renvoie [] en cas d'erreur (menus déroulants, compteurs secondaires).
  static Future<List<Json>> safeList(String endpoint) async {
    try {
      return await Api.list(endpoint);
    } catch (_) {
      return <Json>[];
    }
  }
}
