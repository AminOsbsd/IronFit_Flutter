import 'package:flutter/material.dart';

import '../../core/api/api.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/values.dart';
import '../planning/booking.dart';
import 'module.dart';

const Map<Object, String> roleOptions = {'athlete': 'Membre', 'coach': 'Coach (et membre)'};
const roleLabels = {'admin': 'Administrateur', 'coach': 'Coach', 'athlete': 'Membre'};

/// Mêmes valeurs que [payMethods] (vérifié par les tests).
const Map<Object, String> payOptions = {
  'Espèces': 'Espèces',
  'Carte': 'Carte',
  'Virement': 'Virement',
  'Chèque': 'Chèque',
};

const _staff = ['admin', 'coach'];
const _all = ['admin', 'coach', 'athlete'];
const _admin = ['admin'];

String _or(Object? v, [String fallback = '—']) => v == null || '$v'.isEmpty ? fallback : '$v';

/// Activer / désactiver un compte (admin).
List<RowMenu> accountMenu(Json u) => [
  RowMenu(
    u['active'] == 0 ? 'Réactiver le compte' : 'Désactiver le compte',
    u['active'] == 0 ? Icons.lock_open : Icons.block,
    (c, u) => Api.call('POST', 'members/${u['id']}/status', {'active': u['active'] == 0}),
  ),
];

Widget? disabledBadge(Json u) =>
    u['active'] == 0 ? const Chip(label: Text('Désactivé'), visualDensity: VisualDensity.compact) : null;

const _memberFields = [
  Field('name', 'Nom complet', required: true),
  Field('login', 'Identifiant', required: true),
  Field('email', 'E-mail', type: FieldType.email, required: true),
  Field('password', 'Mot de passe', type: FieldType.password),
  Field('phone', 'Téléphone', type: FieldType.phone),
];

/// Les modules CRUD de l'app. Chaque module apparaît dans « Administration » / « Gestion » selon le rôle.
final List<Module> modules = [
  Module(
    id: 'athletes',
    title: 'Membres',
    singular: 'membre',
    endpoint: 'members',
    icon: Icons.groups,
    read: _admin,
    write: _admin,
    query: () => {'role': 'athlete'},
    menu: accountMenu,
    badge: disabledBadge,
    fields: const [
      ..._memberFields,
      Field('role', 'Rôle', type: FieldType.select, options: roleOptions, initial: 'athlete', required: true),
      Field('plan_id', 'Abonnement', type: FieldType.select, ref: 'plans'),
      Field('sub_end', 'Fin d\'abonnement', type: FieldType.date),
    ],
    titleOf: (m) => _or(m['name']),
    subtitleOf: (m) => '${_or(m['plan_name'], 'Sans abonnement')} · fin ${_or(m['sub_end'])} · @${_or(m['login'], '')}',
  ),
  Module(
    id: 'coaches',
    title: 'Coachs',
    singular: 'coach',
    endpoint: 'members',
    icon: Icons.sports,
    read: _admin,
    write: _admin,
    query: () => {'role': 'coach'},
    menu: accountMenu,
    badge: disabledBadge,
    fields: const [
      ..._memberFields,
      Field('role', 'Rôle', type: FieldType.select, options: roleOptions, initial: 'coach', required: true),
      Field('specialty', 'Spécialité'),
      Field('plan_id', 'Abonnement personnel', type: FieldType.select, ref: 'plans'),
      Field('sub_end', 'Fin d\'abonnement', type: FieldType.date),
    ],
    titleOf: (m) => _or(m['name']),
    subtitleOf: (m) =>
        '${_or(m['specialty'])} · @${_or(m['login'], '')}'
        '${m['sub_end'] == null ? '' : ' · abonné jusqu\'au ${m['sub_end']}'}',
  ),
  Module(
    id: 'classes',
    title: 'Séances & réservations',
    singular: 'séance',
    endpoint: 'classes',
    icon: Icons.event,
    read: _all,
    write: _staff,
    action: bookAction,
    canEditRow: (m) => Api.isAdmin || m['coach_id'] == Api.myId,
    fields: const [
      Field('day', 'Jour', type: FieldType.select, required: true, options: dayOptions),
      Field('time', 'Heure', type: FieldType.time, required: true),
      Field('title', 'Activité', required: true),
      Field('coach_id', 'Coach', type: FieldType.select, ref: 'coaches', roles: _admin),
      Field('spots', 'Places', type: FieldType.number, initial: 10),
    ],
    titleOf: (m) => _or(m['title']),
    subtitleOf: (m) =>
        '${dayNames[toInt(m['day']) % 7]} ${_or(m['time'], '')} · ${_or(m['coach_name'])} · '
        '${toInt(m['taken'])}/${toInt(m['spots'])} réservées',
  ),
  Module(
    id: 'plans',
    title: 'Abonnements & tarifs',
    singular: 'tarif',
    endpoint: 'plans',
    icon: Icons.credit_card,
    read: _all,
    write: _admin,
    fields: const [
      Field('name', 'Nom', required: true),
      Field('price', 'Prix (DT)', type: FieldType.number, required: true),
      Field('duration', 'Durée (ex. 1 mois, 15 jours, 1 entrée)'),
      Field('descr', 'Description', type: FieldType.multiline),
    ],
    titleOf: (m) => '${_or(m['name'])} — ${_or(m['price'], '0')} DT',
    subtitleOf: (m) => '${_or(m['duration'], '')} · ${_or(m['descr'], '')}',
  ),
  Module(
    id: 'promos',
    title: 'Promotions & offres',
    singular: 'offre',
    endpoint: 'promos',
    icon: Icons.local_offer,
    read: _all,
    write: _admin,
    fields: const [
      Field('title', 'Titre', required: true),
      Field('descr', 'Description', type: FieldType.multiline),
      Field('discount', 'Réduction (%)', type: FieldType.number),
      Field('until', 'Valable jusqu\'au', type: FieldType.date),
    ],
    titleOf: (m) => '${_or(m['title'])} (-${_or(m['discount'], '0')}%)',
    subtitleOf: (m) => '${_or(m['descr'], '')} · jusqu\'au ${_or(m['until'])}',
  ),
  Module(
    id: 'payments',
    title: 'Paiements',
    singular: 'paiement',
    endpoint: 'payments',
    icon: Icons.payments,
    read: _all,
    write: _admin,
    fields: const [
      Field('member_id', 'Membre', type: FieldType.select, required: true, ref: 'members'),
      Field('amount', 'Montant (DT)', type: FieldType.number, required: true),
      Field('method', 'Mode de paiement', type: FieldType.select, options: payOptions),
      Field('paid_on', 'Date', type: FieldType.date, today: true),
      Field('note', 'Note'),
    ],
    titleOf: (m) => '${_or(m['amount'], '0')} DT · ${_or(m['method'])}',
    subtitleOf: (m) => '${_or(m['member_name'])} · ${_or(m['paid_on'])} · ${_or(m['note'], '')}',
  ),
  Module(
    id: 'equipment',
    title: 'Matériel',
    singular: 'équipement',
    endpoint: 'equipment',
    icon: Icons.fitness_center,
    read: _staff,
    write: _staff,
    fields: const [
      Field('name', 'Nom', required: true),
      Field(
        'category',
        'Catégorie',
        type: FieldType.select,
        options: {'Cardio': 'Cardio', 'Musculation': 'Musculation', 'Accessoires': 'Accessoires', 'Autre': 'Autre'},
      ),
      Field('qty', 'Quantité', type: FieldType.number, initial: 1),
      Field(
        'status',
        'État',
        type: FieldType.select,
        options: {'OK': 'OK', 'Maintenance': 'Maintenance', 'Hors service': 'Hors service'},
        initial: 'OK',
      ),
    ],
    titleOf: (m) => '${_or(m['name'])} × ${_or(m['qty'], '1')}',
    subtitleOf: (m) => '${_or(m['category'])} · ${_or(m['status'])}',
  ),
  Module(
    id: 'products',
    title: 'Boutique & stock',
    singular: 'produit',
    endpoint: 'products',
    icon: Icons.storefront,
    read: _all,
    write: _admin,
    fields: const [
      Field('name', 'Produit', required: true),
      Field('category', 'Catégorie'),
      Field('price', 'Prix (DT)', type: FieldType.number, required: true),
      Field('stock', 'Stock', type: FieldType.number),
    ],
    titleOf: (m) => '${_or(m['name'])} — ${_or(m['price'], '0')} DT',
    subtitleOf: (m) => '${_or(m['category'])} · stock : ${_or(m['stock'], '0')}',
  ),
  Module(
    id: 'announcements',
    title: 'Annonces',
    singular: 'annonce',
    endpoint: 'announcements',
    icon: Icons.campaign,
    read: _all,
    write: _staff,
    canEditRow: (m) => Api.isAdmin || m['author_id'] == Api.myId,
    fields: const [
      Field('title', 'Titre', required: true),
      Field('body', 'Message', type: FieldType.multiline),
      Field('posted_on', 'Date', type: FieldType.date, today: true),
    ],
    titleOf: (m) => _or(m['title']),
    subtitleOf: (m) =>
        '${_or(m['posted_on'], '')}${m['author_name'] == null ? '' : ' · ${m['author_name']}'} · ${_or(m['body'], '')}',
  ),
  Module(
    id: 'measures',
    title: 'Suivi physique',
    singular: 'mesure',
    endpoint: 'measures',
    icon: Icons.monitor_weight,
    read: _all,
    write: _staff,
    // Coach : uniquement les mesures de ses clients (son suivi personnel est dans « Mon entraînement »)
    query: () => Api.isCoach ? {'scope': 'clients'} : {},
    fields: const [
      Field('member_id', 'Membre', type: FieldType.select, required: true, ref: 'members'),
      Field('measured_on', 'Date', type: FieldType.date, today: true),
      Field('weight', 'Poids (kg)', type: FieldType.number),
      Field('body_fat', 'Masse grasse (%)', type: FieldType.number),
      Field('note', 'Note'),
    ],
    titleOf: (m) => '${_or(m['weight'])} kg · ${_or(m['body_fat'])} % MG',
    subtitleOf: (m) => '${_or(m['member_name'])} · ${_or(m['measured_on'])} · ${_or(m['note'], '')}',
  ),
  Module(
    id: 'checkins',
    title: 'Présences',
    singular: 'présence',
    endpoint: 'checkins',
    icon: Icons.how_to_reg,
    read: _all,
    write: _staff,
    query: () => Api.isCoach ? {'scope': 'clients'} : {},
    fields: const [
      Field('member_id', 'Membre', type: FieldType.select, required: true, ref: 'members'),
      Field('checkin_on', 'Date', type: FieldType.date, today: true),
      Field('note', 'Activité / note'),
    ],
    titleOf: (m) => _or(m['member_name']),
    subtitleOf: (m) => '${_or(m['checkin_on'])} · ${_or(m['note'], '')}',
  ),
];

Module moduleById(String id) => modules.firstWhere((m) => m.id == id);
