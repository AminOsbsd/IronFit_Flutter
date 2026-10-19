/// Lecture tolérante des valeurs JSON renvoyées par le serveur (SQLite : nombres, 0/1, chaînes ou null).
library;

double toDouble(Object? v) => switch (v) {
  final num n => n.toDouble(),
  final String s => double.tryParse(s.replaceAll(',', '.')) ?? 0,
  _ => 0,
};

int toInt(Object? v) => toDouble(v).toInt();

bool asBool(Object? v) => v == 1 || v == true;

/// Première lettre en majuscule, ou `?` si le texte est vide.
String initialOf(Object? name) {
  final s = '${name ?? ''}'.trim();
  return s.isEmpty ? '?' : s[0].toUpperCase();
}

/// Premier mot d'un nom complet.
String firstName(Object? name) => '${name ?? ''}'.trim().split(' ').first;

/// Pluriel français simple : `plural(2, 'séance')` → `2 séances`.
String plural(int n, String word, [String? pluralWord]) => '$n ${n > 1 ? (pluralWord ?? '${word}s') : word}';

const payMethods = ['Espèces', 'Carte', 'Virement', 'Chèque'];
