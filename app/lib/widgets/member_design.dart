import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import 'common_widgets.dart';

bool get isMemberDesign => Api.user != null && !Api.isCoach && !Api.isAdmin;

/// Scoped to signed-in members; coach/admin and authentication retain their theme.
ThemeData memberTheme(ThemeData base) {
  final dark = base.brightness == Brightness.dark;
  final cs = base.colorScheme.copyWith(
    primary: const Color(0xFFFF9800),
    onPrimary: const Color(0xFF171717),
    primaryContainer: dark ? const Color(0xFF49321A) : const Color(0xFFFFE8CA),
    onPrimaryContainer: dark
        ? const Color(0xFFFFE8CA)
        : const Color(0xFF492800),
  );
  return base.copyWith(
    colorScheme: cs,
    scaffoldBackgroundColor: dark
        ? base.scaffoldBackgroundColor
        : const Color(0xFFF7F5F2),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: dark ? cs.surface : const Color(0xFFF7F5F2),
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: base.cardTheme.copyWith(
      color: cs.surface,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: .12),
      margin: const EdgeInsets.symmetric(vertical: 7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: .3)),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      backgroundColor: cs.surface,
      indicatorColor: const Color(0xFFFFB23F),
      elevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
      shape: const CircleBorder(),
    ),
  );
}

class MemberIllustration extends StatelessWidget {
  final double size;
  final bool strength;
  const MemberIllustration({super.key, this.size = 100, this.strength = false});
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Image.asset(
      strength
          ? 'assets/images/member_strength_3d.png'
          : 'assets/images/member_fitness_3d.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * 2).round().clamp(128, 640),
      errorBuilder: (_, _, _) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.fitness_center_rounded, size: 40),
      ),
    ),
  );
}

class MemberEmptyCard extends StatelessWidget {
  final String message, action;
  final VoidCallback onTap;
  const MemberEmptyCard({
    super.key,
    required this.message,
    required this.action,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const MemberIllustration(size: 120),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onTap,
            child: Text(action, textAlign: TextAlign.center),
          ),
        ],
      ),
    ),
  );
}

/// Uses only the fields returned for the dated session; never invents a venue.
class MemberSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final Widget? action;
  final VoidCallback? onTap;
  const MemberSessionCard({
    super.key,
    required this.session,
    this.action,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = session;
    final cs = Theme.of(context).colorScheme;
    final booked = isTrue(c['mine']);
    final status = '${c['attendance_status'] ?? 'pending'}';
    final start = DateTime.tryParse('${c['session_date']}T${c['time']}');
    final past = start != null && !start.isAfter(DateTime.now());
    final color = status == 'present'
        ? const Color(0xFF137A39)
        : status == 'absent'
        ? cs.error
        : past
        ? const Color(0xFF2256A2)
        : const Color(0xFF965300);
    final message = status == 'present'
        ? 'Votre présence a été confirmée !'
        : status == 'absent'
        ? 'Absence enregistrée par votre coach.'
        : past
        ? 'En attente de vérification de présence.'
        : 'Votre présence sera vérifiée par votre coach après le cours.';
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const MemberIllustration(size: 82),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${c['title']}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${c['session_date'] ?? ''} · ${c['time']}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        if (c['coach_name'] != null)
                          Text(
                            'Coach : ${c['coach_name']}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (c['room'] != null || c['location'] != null)
                          Text('${c['room'] ?? c['location']}'),
                      ],
                    ),
                  ),
                ],
              ),
              if (c['spots'] != null) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(
                  value: num2(c['spots']) <= 0
                      ? 0
                      : (num2(c['taken']) / num2(c['spots'])).clamp(0, 1),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 5),
                Text(
                  '${num2(c['taken']).toInt()}/${num2(c['spots']).toInt()} places',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (booked) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        status == 'present'
                            ? Icons.check_circle
                            : status == 'absent'
                            ? Icons.cancel_outlined
                            : Icons.info_outline,
                        color: color,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? cs.onSurface
                                : color,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
