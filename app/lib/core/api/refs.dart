import 'api.dart';

/// Listes de référence (abonnements, coachs, membres) pour les menus déroulants et l'affichage des noms.
class Refs {
  Refs._();

  static final Map<String, List<Json>> data = {};

  static Future<void> load() async {
    final (plans, coaches, members) = await (
      Api.listOrEmpty('plans'),
      Api.listOrEmpty('coaches'),
      // Admin : tous les membres ; coach : ses clients (filtré par le serveur)
      Api.isAdmin || Api.isCoach ? Api.listOrEmpty('members') : Future.value(<Json>[]),
    ).wait;
    data['plans'] = plans;
    data['coaches'] = coaches;
    data['members'] = members;
  }

  /// Nom de l'élément [id] dans la liste [ref], ou `—` s'il est inconnu.
  static String name(String ref, Object? id) {
    if (id == null) return '—';
    if (ref == 'members' && Api.myId == id) return '${Api.me!['name']}';
    for (final r in data[ref] ?? const <Json>[]) {
      if (r['id'] == id) return '${r['name']}';
    }
    return '—';
  }

  static Map<Object, String> options(String ref) => {
    for (final r in data[ref] ?? const <Json>[])
      if (r['id'] != null) r['id'] as Object: '${r['name']}',
  };
}
