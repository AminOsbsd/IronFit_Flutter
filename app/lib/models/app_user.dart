/// Utilisateur connecté (réponse de GET /api/me).
class AppUser {
  final int id;
  final String name, login, email, role;
  final String? phone, specialty, subEnd, planName;
  final int? planId;
  final bool active;

  const AppUser({
    required this.id, required this.name, required this.login, required this.email, required this.role,
    this.phone, this.specialty, this.subEnd, this.planName, this.planId, this.active = true,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: (j['id'] as num).toInt(),
        name: '${j['name'] ?? ''}',
        login: '${j['login'] ?? ''}',
        email: '${j['email'] ?? ''}',
        role: '${j['role'] ?? ''}',
        phone: j['phone'] as String?,
        specialty: j['specialty'] as String?,
        subEnd: j['sub_end'] as String?,
        planName: j['plan_name'] as String?,
        planId: (j['plan_id'] as num?)?.toInt(),
        active: j['active'] != false,
      );

  bool get isAdmin => role == 'admin';
  bool get isCoach => role == 'coach';
  /// Un coach est aussi membre (abonnement, réservations, programmes personnels).
  bool get isMember => role == 'athlete' || role == 'coach';

  String get firstName => name.trim().isEmpty ? login : name.trim().split(RegExp(r'\s+')).first;
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  /// Abonnement en cours à la date du jour.
  bool get hasActiveSubscription {
    final end = DateTime.tryParse(subEnd ?? '');
    if (end == null) return false;
    final now = DateTime.now();
    return !end.isBefore(DateTime(now.year, now.month, now.day));
  }
}
