import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import 'common_widgets.dart';

/// Member-only artwork with responsive layout and reduced-motion support.
class MemberFitnessHero extends StatelessWidget {
  final Widget child;
  const MemberFitnessHero({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    if (Api.isCoach || Api.isAdmin) return HeroCard(child: child);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final art = ExcludeSemantics(
            child: Image.asset(
              'assets/images/member_strength_3d.png',
              height: constraints.maxWidth < 340 ? 150 : 220,
              fit: BoxFit.contain,
              cacheWidth: 640,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.fitness_center_rounded, size: 72),
            ),
          );
          final sideBySide =
              constraints.maxWidth >= 440 &&
              MediaQuery.textScalerOf(context).scale(16) <= 24;
          final content = sideBySide
              ? Row(
                  children: [
                    Expanded(flex: 3, child: child),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: art),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [art, const SizedBox(height: 12), child],
                );
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: reduced ? 1 : 0, end: 1),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 360),
            builder: (_, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 6),
                child: child,
              ),
            ),
            child: content,
          );
        },
      ),
    );
  }
}
