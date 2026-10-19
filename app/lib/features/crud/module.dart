import 'package:flutter/material.dart';

import '../../core/api/api.dart';

enum FieldType { text, number, multiline, date, time, email, phone, password, select }

/// Un champ de formulaire d'un module CRUD.
class Field {
  final String key, label;
  final FieldType type;
  final bool required;

  /// Pré-remplir avec la date du jour à la création.
  final bool today;

  /// Liste fixe de choix (pour [FieldType.select]).
  final Map<Object, String>? options;

  /// Liste chargée depuis le serveur (pour [FieldType.select]) : `plans` | `coaches` | `members`.
  final String? ref;

  /// Valeur par défaut à la création.
  final Object? initial;

  /// Rôles qui voient ce champ (`null` = tous).
  final List<String>? roles;

  const Field(
    this.key,
    this.label, {
    this.type = FieldType.text,
    this.required = false,
    this.today = false,
    this.options,
    this.ref,
    this.initial,
    this.roles,
  }) : assert(type != FieldType.select || options != null || ref != null, 'select needs options or ref');

  bool get visible => roles == null || roles!.contains(Api.role);
}

/// Action affichée à droite d'une ligne (ex. « Réserver »). [reload] recharge la liste.
typedef RowAction = Widget? Function(BuildContext context, Json row, Future<void> Function() reload);

/// Action supplémentaire dans le menu « ⋮ » d'une ligne.
class RowMenu {
  final String label;
  final IconData icon;
  final Future<void> Function(BuildContext context, Json row) run;
  const RowMenu(this.label, this.icon, this.run);
}

/// Un module = une entité CRUD. Ajouter un module = ajouter un bloc dans `module_catalogue.dart`.
/// Les rôles `read` / `write` adaptent l'interface ; le serveur applique ses propres règles d'accès.
class Module {
  final String id, title, singular, endpoint;
  final IconData icon;

  /// Rôles autorisés en lecture / écriture.
  final List<String> read, write;
  final List<Field> fields;
  final String Function(Json) titleOf, subtitleOf;

  /// Paramètres envoyés au serveur (filtre, portée).
  final Map<String, Object?> Function()? query;

  /// Règle par ligne (ex. un coach ne modifie que ses séances).
  final bool Function(Json)? canEditRow;
  final List<RowMenu> Function(Json)? menu;
  final RowAction? action;
  final Widget? Function(Json)? badge;

  const Module({
    required this.id,
    required this.title,
    required this.singular,
    required this.endpoint,
    required this.icon,
    required this.read,
    required this.write,
    required this.fields,
    required this.titleOf,
    required this.subtitleOf,
    this.query,
    this.canEditRow,
    this.menu,
    this.action,
    this.badge,
  });

  bool canRead(String role) => read.contains(role);
  bool canWrite(String role) => write.contains(role);
}
