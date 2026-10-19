/// Dates au format ISO (`AAAA-MM-JJ`) utilisé par le serveur, et libellés en français.
library;

const dayNames = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
const dayShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const monthShort = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Août', 'Sep', 'Oct', 'Nov', 'Déc'];

/// Jours de la semaine pour les listes déroulantes (0 = lundi), cohérent avec [dayNames].
const Map<Object, String> dayOptions = {
  0: 'Lundi',
  1: 'Mardi',
  2: 'Mercredi',
  3: 'Jeudi',
  4: 'Vendredi',
  5: 'Samedi',
  6: 'Dimanche',
};

String twoDigits(int n) => n.toString().padLeft(2, '0');

String isoDate(DateTime d) => '${d.year}-${twoDigits(d.month)}-${twoDigits(d.day)}';

String todayIso([DateTime? now]) => isoDate(now ?? DateTime.now());

/// Indice du jour courant (0 = lundi … 6 = dimanche).
int todayIndex([DateTime? now]) => (now ?? DateTime.now()).weekday - 1;

/// Nombre de jours avant le prochain [day] (0 = aujourd'hui).
int daysAhead(int day, [DateTime? now]) => (day - todayIndex(now)) % 7;

/// "Aujourd'hui" / "Demain" / nom du jour, selon l'indice de jour (0 = lundi).
String dayLabel(int day, [DateTime? now]) => switch (daysAhead(day, now)) {
  0 => 'Aujourd\'hui',
  1 => 'Demain',
  _ => dayNames[day % 7],
};

/// Mois abrégé à partir d'un mois ISO `AAAA-MM` (`?` si invalide).
String monthLabel(String isoMonth) {
  final m = isoMonth.length >= 7 ? int.tryParse(isoMonth.substring(5, 7)) : null;
  return m == null || m < 1 || m > 12 ? '?' : monthShort[m - 1];
}

/// Date ISO sans l'année (`MM-JJ`), pour les affichages compacts.
String withoutYear(String iso) => iso.replaceFirst(RegExp(r'^\d{4}-'), '');

/// Horodatage SQLite (« AAAA-MM-JJ HH:MM:SS », en UTC) → « AAAA-MM-JJ HH:MM » à l'heure locale.
String localStamp(Object? utc) {
  final raw = '${utc ?? ''}';
  final d = DateTime.tryParse('${raw.replaceFirst(' ', 'T')}Z')?.toLocal();
  if (d == null) return raw;
  return '${isoDate(d)} ${twoDigits(d.hour)}:${twoDigits(d.minute)}';
}

/// Partie date (`AAAA-MM-JJ`) d'un horodatage SQLite.
String datePart(Object? stamp) => '${stamp ?? ''}'.split(' ').first;
