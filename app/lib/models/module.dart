import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/theme/app_theme.dart';
import '../services/admin_service.dart';
import '../services/catalog_service.dart';
import '../services/planning_service.dart';
import '../widgets/common_widgets.dart';

const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const Map<Object, String> dayOptions = {0: 'Lundi', 1: 'Mardi', 2: 'Mercredi', 3: 'Jeudi', 4: 'Vendredi', 5: 'Samedi', 6: 'Dimanche'};
const Map<Object, String> roleOptions = {'athlete': 'Membre', 'coach': 'Coach (et membre)'};
const roleLabels = {'admin': 'Administrateur', 'coach': 'Coach', 'athlete': 'Membre'};

enum FT { text, number, multiline, date, time, email, phone, password, select }

class Field {
  final String key, label;
  final FT type;
  final bool required, today;
  final Map<Object, String>? options; // liste fixe
  final String? ref; // liste chargée depuis le serveur : plans | coaches | members
  final Object? initial; // valeur par défaut à la création
  final List<String>? roles; // rôles qui voient ce champ (null = tous)
  const Field(this.key, this.label, {this.type = FT.text, this.required = false, this.today = false, this.options, this.ref, this.initial, this.roles});
  bool get visible => roles == null || roles!.contains(Api.role);
}

typedef RowAction = Widget? Function(BuildContext, Map<String, dynamic>, Future<void> Function() reload);

/// Action supplémentaire dans le menu « ⋮ » d'une ligne.
class RowMenu {
  final String label;
  final IconData icon;
  final Future<void> Function(BuildContext, Map<String, dynamic>) run;
  const RowMenu(this.label, this.icon, this.run);
}

/// Un module = une entité CRUD. Ajouter un module = ajouter un bloc ci-dessous.
/// Les rôles `read` / `write` adaptent l'interface ; le serveur applique ses propres règles d'accès.
class Module {
  final String id, title, singular, endpoint;
  final IconData icon;
  final List<String> read, write; // rôles autorisés
  final List<Field> fields;
  final String Function(Map<String, dynamic>) titleOf, subtitleOf;
  final Map<String, Object?> Function()? query; // paramètres envoyés au serveur (filtre, portée)
  final bool Function(Map<String, dynamic>)? canEditRow; // ex. un coach ne modifie que ses séances
  final List<RowMenu> Function(Map<String, dynamic>)? menu;
  final RowAction? action;
  final Widget? Function(Map<String, dynamic>)? badge;
  Module({
    required this.id, required this.title, required this.singular, required this.endpoint, required this.icon,
    required this.read, required this.write, required this.fields, required this.titleOf, required this.subtitleOf,
    this.query, this.canEditRow, this.menu, this.action, this.badge,
  });
}

/// Listes de référence (abonnements, coachs, membres) pour les menus déroulants.
class Refs {
  static final Map<String, List<Map<String, dynamic>>> data = {};

  static Future<void> load() async {
    data['plans'] = await CrudService.safeList('plans');
    data['coaches'] = await CrudService.safeList('coaches');
    // Admin : tous les membres ; coach : ses clients (filtré par le serveur)
    data['members'] = Api.isAdmin || Api.isCoach ? await CrudService.safeList('members') : <Map<String, dynamic>>[];
  }

  static String name(String ref, dynamic id) {
    if (id == null) return '—';
    if (ref == 'members' && Api.myId == id) return Api.user!.name;
    for (final r in data[ref] ?? <Map<String, dynamic>>[]) {
      if (r['id'] == id) return '${r['name']}';
    }
    return '—';
  }

  static Map<Object, String> options(String ref) => {
        for (final r in data[ref] ?? <Map<String, dynamic>>[]) (r['id'] as Object): '${r['name']}',
      };
}

Widget? bookAction(BuildContext c, Map<String, dynamic> x, Future<void> Function() reload) {
  if (!Api.isMember || Api.inCoachSpace) return null;
  final mine = isTrue(x['mine']);
  if (x['coach_id'] == Api.myId) return null; // il anime cette séance
  final full = ((x['taken'] ?? 0) as num) >= ((x['spots'] ?? 0) as num) && !mine;
  return FilledButton(
    style: mine ? FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.secondaryContainer, foregroundColor: Theme.of(c).colorScheme.onSecondaryContainer) : null,
    onPressed: full
        ? null
        : () async {
            try {
              await PlanningService.toggleBooking(x['id'] as int);
              await reload();
            } catch (e) {
              if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$e')));
            }
          },
    child: Text(mine ? 'Annuler' : (full ? 'Complet' : 'Réserver')),
  );
}

/// Activer / désactiver un compte (admin).
List<RowMenu> accountMenu(Map<String, dynamic> u) => [
      RowMenu(u['active'] == false ? 'Réactiver le compte' : 'Désactiver le compte', u['active'] == false ? Icons.lock_open : Icons.block, (c, u) async {
        await AdminService.setAccountActive(u['id'] as int, u['active'] == false);
      }),
    ];

Widget? disabledBadge(Map<String, dynamic> u) => u['active'] == false ? const StatusPill('Désactivé', color: AppColors.danger, icon: Icons.block) : null;

const _staff = ['admin', 'coach'];
const _all = ['admin', 'coach', 'athlete'];

const _memberFields = [
  Field('name', 'Nom complet', required: true),
  Field('login', 'Identifiant', required: true),
  Field('email', 'E-mail', type: FT.email, required: true),
  Field('password', 'Mot de passe', type: FT.password),
  Field('phone', 'Téléphone', type: FT.phone),
];

final List<Module> modules = [
  Module(
    id: 'athletes', title: 'Membres', singular: 'membre', endpoint: 'members', icon: Icons.groups,
    read: ['admin'], write: ['admin'], query: () => {'role': 'athlete'}, menu: accountMenu, badge: disabledBadge,
    fields: const [
      ..._memberFields,
      Field('role', 'Rôle', type: FT.select, options: roleOptions, initial: 'athlete', required: true),
      Field('plan_id', 'Abonnement', type: FT.select, ref: 'plans'),
      Field('sub_end', 'Fin d\'abonnement', type: FT.date),
    ],
    titleOf: (m) => '${m['name']}',
    subtitleOf: (m) => '${m['plan_name'] ?? 'Sans abonnement'} · fin ${m['sub_end'] ?? '—'} · @${m['login']}',
  ),
  Module(
    id: 'coaches', title: 'Coachs', singular: 'coach', endpoint: 'members', icon: Icons.sports,
    read: ['admin'], write: ['admin'], query: () => {'role': 'coach'}, menu: accountMenu, badge: disabledBadge,
    fields: const [
      ..._memberFields,
      Field('role', 'Rôle', type: FT.select, options: roleOptions, initial: 'coach', required: true),
      Field('specialty', 'Spécialité'),
      Field('plan_id', 'Abonnement personnel', type: FT.select, ref: 'plans'),
      Field('sub_end', 'Fin d\'abonnement', type: FT.date),
    ],
    titleOf: (m) => '${m['name']}',
    subtitleOf: (m) => '${m['specialty'] ?? '—'} · @${m['login']}${m['sub_end'] == null ? '' : ' · abonné jusqu\'au ${m['sub_end']}'}',
  ),
  Module(
    id: 'classes', title: 'Séances & réservations', singular: 'séance', endpoint: 'classes', icon: Icons.event,
    read: _all, write: _staff, action: bookAction,
    canEditRow: (m) => Api.isAdmin || m['coach_id'] == Api.myId,
    fields: const [
      Field('day', 'Jour', type: FT.select, required: true, options: dayOptions),
      Field('time', 'Heure', type: FT.time, required: true),
      Field('title', 'Activité', required: true),
      Field('coach_id', 'Coach', type: FT.select, ref: 'coaches', roles: ['admin']),
      Field('spots', 'Places', type: FT.number, initial: 10),
    ],
    titleOf: (m) => '${m['title']}',
    subtitleOf: (m) => '${days[((m['day'] ?? 0) as int) % 7]} ${m['time']} · ${m['coach_name'] ?? '—'} · ${m['taken']}/${m['spots']} réservées',
  ),
  Module(
    id: 'plans', title: 'Abonnements & tarifs', singular: 'tarif', endpoint: 'plans', icon: Icons.credit_card,
    read: _all, write: ['admin'],
    fields: const [
      Field('name', 'Nom', required: true),
      Field('price', 'Prix (DT)', type: FT.number, required: true),
      Field('duration', 'Durée (ex. 1 mois, 15 jours, 1 entrée)'),
      Field('descr', 'Description', type: FT.multiline),
    ],
    titleOf: (m) => '${m['name']} — ${money(m['price'])}',
    subtitleOf: (m) => '${m['duration'] ?? ''} · ${m['descr'] ?? ''}',
  ),
  Module(
    id: 'promos', title: 'Promotions & offres', singular: 'offre', endpoint: 'promos', icon: Icons.local_offer,
    read: _all, write: ['admin'],
    fields: const [
      Field('title', 'Titre', required: true),
      Field('descr', 'Description', type: FT.multiline),
      Field('discount', 'Réduction (%)', type: FT.number),
      Field('until', 'Valable jusqu\'au', type: FT.date),
    ],
    titleOf: (m) => '${m['title']} (-${m['discount'] ?? 0}%)',
    subtitleOf: (m) => '${m['descr'] ?? ''} · jusqu\'au ${m['until'] ?? '—'}',
  ),
  Module(
    id: 'payments', title: 'Paiements', singular: 'paiement', endpoint: 'payments', icon: Icons.payments,
    read: _all, write: ['admin'],
    fields: const [
      Field('member_id', 'Membre', type: FT.select, required: true, ref: 'members'),
      Field('amount', 'Montant (DT)', type: FT.number, required: true),
      Field('method', 'Mode de paiement', type: FT.select, options: {'Espèces': 'Espèces', 'Carte': 'Carte', 'Virement': 'Virement', 'Chèque': 'Chèque'}),
      Field('paid_on', 'Date', type: FT.date, today: true),
      Field('note', 'Note'),
    ],
    titleOf: (m) => '${money(m['amount'])} · ${m['method'] ?? '—'}',
    subtitleOf: (m) => '${m['member_name'] ?? '—'} · ${m['paid_on'] ?? '—'} · ${m['note'] ?? ''}',
  ),
  Module(
    id: 'equipment', title: 'Matériel', singular: 'équipement', endpoint: 'equipment', icon: Icons.fitness_center,
    read: _staff, write: _staff,
    fields: const [
      Field('name', 'Nom', required: true),
      Field('category', 'Catégorie', type: FT.select, options: {'Cardio': 'Cardio', 'Musculation': 'Musculation', 'Accessoires': 'Accessoires', 'Autre': 'Autre'}),
      Field('qty', 'Quantité', type: FT.number, initial: 1),
      Field('status', 'État', type: FT.select, options: {'OK': 'OK', 'Maintenance': 'Maintenance', 'Hors service': 'Hors service'}, initial: 'OK'),
    ],
    titleOf: (m) => '${m['name']} × ${m['qty'] ?? 1}',
    subtitleOf: (m) => '${m['category'] ?? '—'} · ${m['status'] ?? '—'}',
  ),
  Module(
    id: 'products', title: 'Boutique & stock', singular: 'produit', endpoint: 'products', icon: Icons.storefront,
    read: _all, write: ['admin'],
    fields: const [
      Field('name', 'Produit', required: true),
      Field('category', 'Catégorie'),
      Field('price', 'Prix (DT)', type: FT.number, required: true),
      Field('stock', 'Stock', type: FT.number),
    ],
    titleOf: (m) => '${m['name']} — ${money(m['price'])}',
    subtitleOf: (m) => '${m['category'] ?? '—'} · stock : ${m['stock'] ?? 0}',
  ),
  Module(
    id: 'announcements', title: 'Annonces', singular: 'annonce', endpoint: 'announcements', icon: Icons.campaign,
    read: _all, write: _staff,
    canEditRow: (m) => Api.isAdmin || m['author_id'] == Api.myId,
    fields: const [
      Field('title', 'Titre', required: true),
      Field('body', 'Message', type: FT.multiline),
      Field('posted_on', 'Date', type: FT.date, today: true),
    ],
    titleOf: (m) => '${m['title']}',
    subtitleOf: (m) => '${m['posted_on'] ?? ''}${m['author_name'] == null ? '' : ' · ${m['author_name']}'} · ${m['body'] ?? ''}',
  ),
  Module(
    id: 'measures', title: 'Suivi physique', singular: 'mesure', endpoint: 'measures', icon: Icons.monitor_weight,
    read: _all, write: _staff,
    // Coach : uniquement les mesures de ses clients (son suivi personnel est dans « Mon entraînement »)
    query: () => Api.isCoach ? {'scope': 'clients'} : {},
    fields: const [
      Field('member_id', 'Membre', type: FT.select, required: true, ref: 'members'),
      Field('measured_on', 'Date', type: FT.date, today: true),
      Field('weight', 'Poids (kg)', type: FT.number),
      Field('body_fat', 'Masse grasse (%)', type: FT.number),
      Field('note', 'Note'),
    ],
    titleOf: (m) => '${m['weight'] ?? '—'} kg · ${m['body_fat'] ?? '—'} % MG',
    subtitleOf: (m) => '${m['member_name'] ?? '—'} · ${m['measured_on'] ?? '—'} · ${m['note'] ?? ''}',
  ),
  Module(
    id: 'checkins', title: 'Présences', singular: 'présence', endpoint: 'checkins', icon: Icons.how_to_reg,
    read: _all, write: _staff,
    query: () => Api.isCoach ? {'scope': 'clients'} : {},
    fields: const [
      Field('member_id', 'Membre', type: FT.select, required: true, ref: 'members'),
      Field('checkin_on', 'Date', type: FT.date, today: true),
      Field('note', 'Activité / note'),
    ],
    titleOf: (m) => '${m['member_name'] ?? '—'}',
    subtitleOf: (m) => '${m['checkin_on'] ?? '—'} · ${m['note'] ?? ''}',
  ),
];

Module moduleById(String id) => modules.firstWhere((m) => m.id == id);
