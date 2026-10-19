import '../../core/utils/dates.dart';

/// État de l'abonnement d'un athlète, calculé à partir de sa date de fin (`sub_end`, ISO).
class SubscriptionStatus {
  final String? end;
  final bool active;

  /// Jours restants, fin incluse (1 = expire ce soir). 0 si inactif.
  final int daysLeft;

  const SubscriptionStatus._(this.end, this.active, this.daysLeft);

  factory SubscriptionStatus.of(String? end, {DateTime? now}) {
    final endDate = end == null ? null : DateTime.tryParse(end);
    if (endDate == null) return SubscriptionStatus._(end, false, 0);
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final days = DateTime(endDate.year, endDate.month, endDate.day).difference(today).inDays + 1;
    return SubscriptionStatus._(end, days > 0, days > 0 ? days : 0);
  }

  bool get hasPlan => end != null;

  String get label {
    if (end == null) return 'Aucun abonnement';
    if (DateTime.tryParse(end!) == null) return 'Date de fin invalide';
    if (!active) return 'Expiré le $end';
    return 'Actif · $daysLeft jour${daysLeft > 1 ? 's' : ''} restant${daysLeft > 1 ? 's' : ''}';
  }
}

/// `true` si la date ISO [iso] est strictement avant aujourd'hui.
bool isPast(Object? iso, {DateTime? now}) => iso != null && '$iso'.compareTo(todayIso(now)) < 0;
