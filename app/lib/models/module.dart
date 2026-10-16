import 'package:flutter/material.dart';
import '../services/api_service.dart';

const days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const Map<Object, String> dayOptions = {0: 'Lundi', 1: 'Mardi', 2: 'Mercredi', 3: 'Jeudi', 4: 'Vendredi', 5: 'Samedi', 6: 'Dimanche'};

enum FT { text, number, multiline, date, time, email, phone, password, select }

class Field {
  final String key, label;
  final FT type;
  final bool required, today;
  final Map<Object, String>? options; // liste fixe
  final String? ref; // liste chargée depuis le serveur: plans | coaches | athletes
  const Field(this.key, this.label, {this.type = FT.text, this.required = false, this.today = false, this.options, this.ref});
}

typedef RowAction = Widget? Function(BuildContext, Map<String, dynamic>, Future<void> Function() reload);

/// Un module = une entité CRUD. Ajouter un module = ajouter un bloc ci-dessous.
class Module {
  final String id, title, singular, endpoint;
  final IconData icon;
  final List<String> read, write; // rôles autorisés
  final List<Field> fields;
  final String Function(Map<String, dynamic>) titleOf, subtitleOf;
  final bool Function(Map<String, dynamic>)? filter;
  final Map<String, dynamic> extra;
  final RowAction? action;
  Module({
    required this.id, required this.title, required this.singular, required this.endpoint, required this.icon,
    required this.read, required this.write, required this.fields, required this.titleOf, required this.subtitleOf,
    this.filter, this.extra = const {}, this.action,
  });
}

/// Listes de référence (abonnements, coachs, athlètes) pour les menus déroulants.
class Refs {
  static final Map<String, List<Map<String, dynamic>>> data = {};

  static Future<void> load() async {
    Future<List<Map<String, dynamic>>> safe(String ep) async {
      try {
        return await Api.list(ep);
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    }

    data['plans'] = await safe('plans');
    data['coaches'] = await safe('coaches');
    data['athletes'] = Api.role == 'athlete' ? <Map<String, dynamic>>[] : (await safe('members')).where((m) => m['role'] == 'athlete').toList();
  }

  static String name(String ref, dynamic id) {
    if (id == null) return '—';
    if (ref == 'athletes' && Api.me?['id'] == id) return '${Api.me!['name']}';
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
  if (Api.role != 'athlete') return null;
  final mine = x['mine'] == 1 || x['mine'] == true;
  final full = ((x['taken'] ?? 0) as num) >= ((x['spots'] ?? 0) as num) && !mine;
  return FilledButton.tonal(
    onPressed: full
        ? null
        : () async {
            try {
              await Api.call('POST', 'book', {'class_id': x['id']});
              await reload();
            } catch (e) {
              if (c.mounted) ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text('$e')));
            }
          },
    child: Text(mine ? 'Annuler' : (full ? 'Complet' : 'Réserver')),
  );
}

const _staff = ['admin', 'coach'];
const _all = ['admin', 'coach', 'athlete'];

final List<Module> modules = [
  Module(
    id: 'athletes', title: 'Athlètes', singular: 'athlète', endpoint: 'members', icon: Icons.groups,
    read: _staff, write: ['admin'], extra: {'role': 'athlete'}, filter: (m) => m['role'] == 'athlete',
    fields: const [
      Field('name', 'Nom complet', required: true),
      Field('login', 'Identifiant', required: true),
      Field('email', 'E-mail', type: FT.email, required: true),
      Field('password', 'Mot de passe', type: FT.password),
      Field('phone', 'Téléphone', type: FT.phone),
      Field('plan_id', 'Abonnement', type: FT.select, ref: 'plans'),
      Field('sub_end', 'Fin d\'abonnement', type: FT.date),
    ],
    titleOf: (m) => '${m['name']}',
    subtitleOf: (m) => '${Refs.name('plans', m['plan_id'])} · fin ${m['sub_end'] ?? '—'} · @${m['login']}',
  ),
  Module(
    id: 'coaches', title: 'Coachs', singular: 'coach', endpoint: 'members', icon: Icons.sports,
    read: ['admin'], write: ['admin'], extra: {'role': 'coach'}, filter: (m) => m['role'] == 'coach',
    fields: const [
      Field('name', 'Nom complet', required: true),
      Field('login', 'Identifiant', required: true),
      Field('email', 'E-mail', type: FT.email, required: true),
      Field('password', 'Mot de passe', type: FT.password),
      Field('phone', 'Téléphone', type: FT.phone),
      Field('specialty', 'Spécialité'),
    ],
    titleOf: (m) => '${m['name']}',
    subtitleOf: (m) => '${m['specialty'] ?? ''} · @${m['login']}',
  ),
  Module(
    id: 'classes', title: 'Séances & réservations', singular: 'séance', endpoint: 'classes', icon: Icons.event,
    read: _all, write: _staff, action: bookAction,
    fields: const [
      Field('day', 'Jour', type: FT.select, required: true, options: dayOptions),
      Field('time', 'Heure', type: FT.time, required: true),
      Field('title', 'Activité', required: true),
      Field('coach_id', 'Coach', type: FT.select, ref: 'coaches'),
      Field('spots', 'Places', type: FT.number),
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
      Field('duration', 'Durée'),
      Field('descr', 'Description', type: FT.multiline),
    ],
    titleOf: (m) => '${m['name']} — ${m['price']} DT',
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
    read: ['admin', 'athlete'], write: ['admin'],
    fields: const [
      Field('member_id', 'Athlète', type: FT.select, required: true, ref: 'athletes'),
      Field('amount', 'Montant (DT)', type: FT.number, required: true),
      Field('method', 'Mode de paiement', type: FT.select, options: {'Espèces': 'Espèces', 'Carte': 'Carte', 'Virement': 'Virement', 'Chèque': 'Chèque'}),
      Field('paid_on', 'Date', type: FT.date, today: true),
      Field('note', 'Note'),
    ],
    titleOf: (m) => '${m['amount']} DT · ${m['method'] ?? '—'}',
    subtitleOf: (m) => '${Refs.name('athletes', m['member_id'])} · ${m['paid_on'] ?? '—'} · ${m['note'] ?? ''}',
  ),
  Module(
    id: 'equipment', title: 'Matériel', singular: 'équipement', endpoint: 'equipment', icon: Icons.fitness_center,
    read: _staff, write: _staff,
    fields: const [
      Field('name', 'Nom', required: true),
      Field('category', 'Catégorie', type: FT.select, options: {'Cardio': 'Cardio', 'Musculation': 'Musculation', 'Accessoires': 'Accessoires', 'Autre': 'Autre'}),
      Field('qty', 'Quantité', type: FT.number),
      Field('status', 'État', type: FT.select, options: {'OK': 'OK', 'Maintenance': 'Maintenance', 'Hors service': 'Hors service'}),
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
    titleOf: (m) => '${m['name']} — ${m['price']} DT',
    subtitleOf: (m) => '${m['category'] ?? '—'} · stock : ${m['stock'] ?? 0}',
  ),
  Module(
    id: 'announcements', title: 'Annonces', singular: 'annonce', endpoint: 'announcements', icon: Icons.campaign,
    read: _all, write: _staff,
    fields: const [
      Field('title', 'Titre', required: true),
      Field('body', 'Message', type: FT.multiline),
      Field('posted_on', 'Date', type: FT.date, today: true),
    ],
    titleOf: (m) => '${m['title']}',
    subtitleOf: (m) => '${m['posted_on'] ?? ''} · ${m['body'] ?? ''}',
  ),
  Module(
    id: 'measures', title: 'Suivi physique', singular: 'mesure', endpoint: 'measures', icon: Icons.monitor_weight,
    read: _all, write: _staff,
    fields: const [
      Field('member_id', 'Athlète', type: FT.select, required: true, ref: 'athletes'),
      Field('measured_on', 'Date', type: FT.date, today: true),
      Field('weight', 'Poids (kg)', type: FT.number),
      Field('body_fat', 'Masse grasse (%)', type: FT.number),
      Field('note', 'Note'),
    ],
    titleOf: (m) => '${m['weight'] ?? '—'} kg · ${m['body_fat'] ?? '—'} % MG',
    subtitleOf: (m) => '${Refs.name('athletes', m['member_id'])} · ${m['measured_on'] ?? '—'} · ${m['note'] ?? ''}',
  ),
  Module(
    id: 'checkins', title: 'Présences', singular: 'présence', endpoint: 'checkins', icon: Icons.how_to_reg,
    read: _all, write: _staff,
    fields: const [
      Field('member_id', 'Athlète', type: FT.select, required: true, ref: 'athletes'),
      Field('checkin_on', 'Date', type: FT.date, today: true),
      Field('note', 'Activité / note'),
    ],
    titleOf: (m) => '${Refs.name('athletes', m['member_id'])}',
    subtitleOf: (m) => '${m['checkin_on'] ?? '—'} · ${m['note'] ?? ''}',
  ),
];

Module moduleById(String id) => modules.firstWhere((m) => m.id == id);
