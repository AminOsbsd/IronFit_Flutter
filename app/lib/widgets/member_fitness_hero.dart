import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import 'common_widgets.dart';
import 'member_design.dart';

class MemberFitnessHero extends StatelessWidget {
  final Widget child;
  const MemberFitnessHero({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    if (Api.isCoach || Api.isAdmin) return HeroCard(child: child);
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF171717), Color(0xFF343235)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -65,
            top: -65,
            child: IgnorePointer(
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFF9800).withValues(alpha: .15),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= 300 &&
                    MediaQuery.textScalerOf(context).scale(16) < 25;
                final content = wide
                    ? Row(
                        children: [
                          Expanded(flex: 3, child: child),
                          const SizedBox(width: 16),
                          const Expanded(
                            flex: 2,
                            child: MemberIllustration(size: 190),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerRight,
                            child: MemberIllustration(size: 90),
                          ),
                          child,
                        ],
                      );
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: reduced ? 1 : 0, end: 1),
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  builder: (_, value, child) =>
                      Opacity(opacity: value, child: child),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(color: Colors.white),
                    child: content,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
