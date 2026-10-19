import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'spacing.dart';

/// Thème Material 3 unique de l'app (clair et sombre).
abstract final class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: AppColors.brand, brightness: brightness);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final t = base.textTheme;
    final radius = BorderRadius.circular(Gaps.radius);
    final inputRadius = BorderRadius.circular(12);

    return base.copyWith(
      extensions: [brightness == Brightness.light ? AppColors.light : AppColors.dark],
      textTheme: t.copyWith(
        headlineMedium: t.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        headlineSmall: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(centerTitle: false, backgroundColor: scheme.surface, scrolledUnderElevation: 1),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: OutlineInputBorder(borderRadius: inputRadius),
        enabledBorder: OutlineInputBorder(
          borderRadius: inputRadius,
          borderSide: BorderSide(color: scheme.outline),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(64, 48), shape: const StadiumBorder()),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48), shape: const StadiumBorder()),
      ),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
      chipTheme: base.chipTheme.copyWith(shape: const StadiumBorder()),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: Gaps.lg)),
    );
  }
}
