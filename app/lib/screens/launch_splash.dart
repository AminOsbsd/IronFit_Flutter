import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/brand.dart';

/// Lives at the root route: initialization and the short introduction run together.
/// Authentication rebuilds and navigation preserve this State, so it never replays.
class LaunchSplash extends StatefulWidget {
  final Future<void> Function() initialize;
  final WidgetBuilder destination;
  final bool skipAnimation;
  const LaunchSplash({
    super.key,
    required this.initialize,
    required this.destination,
    this.skipAnimation = false,
  });

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  bool _started = false, _ready = false, _failed = false;
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    );
    final reveal = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.48, curve: Curves.easeOutCubic),
    );
    _opacity = Tween<double>(begin: 0, end: 1).animate(reveal);
    _scale = Tween<double>(begin: 0.94, end: 1).animate(reveal);
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) setState(() {});
    });
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.initialize();
      if (mounted)
        setState(() {
          _ready = true;
          _failed = false;
        });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (_reducedMotion || widget.skipAnimation) {
      _intro.value = 1;
    } else if (!_started) {
      _intro.forward();
    }
    _started = true;
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _ready && _intro.isCompleted;
    return AnimatedSwitcher(
      duration: _reducedMotion
          ? Duration.zero
          : const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: finished
          ? KeyedSubtree(
              key: const ValueKey('launch-destination'),
              child: widget.destination(context),
            )
          : SizedBox.expand(
              key: const ValueKey('launch-splash'),
              child: ColoredBox(
                color: AppColors.ink,
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final size = (constraints.maxWidth * 0.48)
                          .clamp(140.0, 280.0)
                          .clamp(0.0, constraints.maxHeight * 0.52)
                          .toDouble();
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          ExcludeSemantics(
                            child: Center(
                              child: Container(
                                width: size * 1.65,
                                height: size * 1.65,
                                decoration: BoxDecoration(
                                  gradient: RadialGradient(
                                    colors: [
                                      AppColors.amber.withValues(alpha: 0.055),
                                      AppColors.ink.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Center(
                            child: RepaintBoundary(
                              child: FadeTransition(
                                opacity: _opacity,
                                child: ScaleTransition(
                                  scale: _scale,
                                  child: BrandLogo(
                                    size: size,
                                    transparent: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 24,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_failed) ...[
                                  const Text(
                                    'Le démarrage a été interrompu.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () {
                                      setState(() => _failed = false);
                                      _initialize();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.amber,
                                    ),
                                    child: const Text('Réessayer'),
                                  ),
                                ] else if (_intro.isCompleted && !_ready)
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      'Préparation de votre espace…',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    width: 32,
                                    height: 2,
                                    decoration: BoxDecoration(
                                      color: AppColors.amber.withValues(
                                        alpha: 0.6,
                                      ),
                                      borderRadius: BorderRadius.circular(1),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }
}
