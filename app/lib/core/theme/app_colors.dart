import 'package:flutter/material.dart';

/// Couleurs de marque et couleurs sémantiques (succès / attention / danger), adaptées au mode clair ou sombre.
///
/// Toutes les combinaisons texte / fond utilisées respectent un contraste ≥ 4,5:1 (WCAG AA).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  /// Couleur de marque (orange IronFit), utilisée comme graine du `ColorScheme`.
  static const brand = Color(0xFFEA580C);

  /// Dégradé de la carte membre active (texte blanc ≥ 5:1 sur toute la surface).
  static const brandGradient = [Color(0xFF9A3412), Color(0xFFC2410C)];

  /// Dégradé neutre de la carte membre inactive (texte blanc ≥ 7:1).
  static const inactiveGradient = [Color(0xFF334155), Color(0xFF475569)];

  final Color success, warning, danger;

  const AppColors({required this.success, required this.warning, required this.danger});

  static const light = AppColors(success: Color(0xFF15803D), warning: Color(0xFFB45309), danger: Color(0xFFB91C1C));
  static const dark = AppColors(success: Color(0xFF4ADE80), warning: Color(0xFFFBBF24), danger: Color(0xFFF87171));

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>() ?? light;

  @override
  AppColors copyWith({Color? success, Color? warning, Color? danger}) =>
      AppColors(success: success ?? this.success, warning: warning ?? this.warning, danger: danger ?? this.danger);

  @override
  AppColors lerp(covariant AppColors? other, double t) => other == null
      ? this
      : AppColors(
          success: Color.lerp(success, other.success, t)!,
          warning: Color.lerp(warning, other.warning, t)!,
          danger: Color.lerp(danger, other.danger, t)!,
        );
}
