import 'package:flutter/material.dart';
import 'brand.dart';

/// Couleurs de la marque, tirées du logo IronFit (noir, ambre doré, blanc) + un orange énergique.
class AppColors {
  AppColors._();
  static const ink = Color(0xFF0B0B0D);
  static const charcoal = Color(0xFF17181C);
  static const graphite = Color(0xFF2A2B30);
  static const amber = Color(0xFFFFB547); // ambre du logo
  static const amberDeep = Color(0xFFE08A00); // ambre lisible sur fond clair (éléments larges, icônes)
  static const amberText = Color(0xFFA35C00); // texte ambre sur fond clair (contraste AA)
  static const ember = Color(0xFFFF6B2C); // orange énergique (accent secondaire)
  static const success = Color(0xFF1E9E5A);
  static const warning = Color(0xFFE58A00);
  static const danger = Color(0xFFD92D20);
  static const info = Color(0xFF2F6FED);

  /// Dégradé des cartes « héros » (carte membre, bandeaux).
  static const heroGradient = LinearGradient(colors: [Color(0xFF141519), Color(0xFF2B2C33)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const amberGradient = LinearGradient(colors: [amber, ember], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

/// Thèmes clair et sombre partagés par les espaces membre, coach et administration.
class AppTheme {
  AppTheme._();

  static const radius = 16.0;

  static const _light = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.amberDeep,
    onPrimary: Color(0xFF1A1100),
    primaryContainer: Color(0xFFFFE6BF),
    onPrimaryContainer: Color(0xFF3A2400),
    secondary: AppColors.charcoal,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFECE9E4),
    onSecondaryContainer: Color(0xFF1C1C1E),
    tertiary: AppColors.ember,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFE0D2),
    onTertiaryContainer: Color(0xFF3A1200),
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Colors.white,
    onSurface: Color(0xFF17181C),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFFBFAF8),
    surfaceContainer: Color(0xFFF5F3EF),
    surfaceContainerHigh: Color(0xFFEFECE7),
    surfaceContainerHighest: Color(0xFFE8E4DE),
    onSurfaceVariant: Color(0xFF5A5D66),
    outline: Color(0xFFBDB7AE),
    outlineVariant: Color(0xFFE4DFD8),
    inverseSurface: AppColors.charcoal,
    onInverseSurface: Colors.white,
    inversePrimary: AppColors.amber,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static const _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.amber,
    onPrimary: Color(0xFF1A1100),
    primaryContainer: Color(0xFF4A3200),
    onPrimaryContainer: Color(0xFFFFDDA6),
    secondary: Color(0xFFF2F2F3),
    onSecondary: AppColors.ink,
    secondaryContainer: AppColors.graphite,
    onSecondaryContainer: Color(0xFFEDEDEE),
    tertiary: Color(0xFFFF8A55),
    onTertiary: Color(0xFF2A0D00),
    tertiaryContainer: Color(0xFF5A2410),
    onTertiaryContainer: Color(0xFFFFDBCC),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF3A0000),
    errorContainer: Color(0xFF7A1A12),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF131418),
    onSurface: Color(0xFFF1F1F3),
    surfaceContainerLowest: Color(0xFF0E0F12),
    surfaceContainerLow: Color(0xFF18191D),
    surfaceContainer: Color(0xFF1D1E23),
    surfaceContainerHigh: Color(0xFF24262C),
    surfaceContainerHighest: Color(0xFF2C2E35),
    onSurfaceVariant: Color(0xFFA8ABB4),
    outline: Color(0xFF4A4D57),
    outlineVariant: Color(0xFF2F3139),
    inverseSurface: Color(0xFFF1F1F3),
    onInverseSurface: AppColors.charcoal,
    inversePrimary: AppColors.amberDeep,
    shadow: Colors.black,
    scrim: Colors.black,
  );

  static ThemeData light() => _build(_light, const Color(0xFFF6F4F0));
  static ThemeData dark() => _build(_dark, AppColors.ink);

  static ThemeData _build(ColorScheme cs, Color background) {
    final isDark = cs.brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: cs, brightness: cs.brightness);
    final text = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);
    // Texte ambre : version foncée sur fond clair pour rester lisible (contraste AA)
    final linkColor = isDark ? AppColors.amber : AppColors.amberText;

    return base.copyWith(
      // Fond transparent : chaque page reçoit le fond de marque (couleur + filigrane du logo), voir BrandPageTransitionsBuilder
      scaffoldBackgroundColor: Colors.transparent,
      canvasColor: background,
      textTheme: text,
      pageTransitionsTheme: BrandPageTransitionsBuilder.theme(background),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: cs.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(color: cs.onSurface, fontSize: 22),
      ),
      cardTheme: CardThemeData(
        color: cs.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 5),
        shape: shape.copyWith(side: BorderSide(color: cs.outlineVariant)),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: ListTileThemeData(
        shape: shape,
        iconColor: cs.onSurfaceVariant,
        titleTextStyle: text.titleSmall?.copyWith(color: cs.onSurface, fontSize: 15),
        subtitleTextStyle: text.bodySmall?.copyWith(color: cs.onSurfaceVariant, fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: buttonShape, padding: buttonPadding, textStyle: text.labelLarge),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(shape: buttonShape, padding: buttonPadding, elevation: 0),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: buttonShape,
          padding: buttonPadding,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outline),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: linkColor, shape: buttonShape, textStyle: text.labelLarge),
      ),
      iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: cs.onSurface)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        extendedTextStyle: text.labelLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? cs.surfaceContainerHigh : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: cs.error, width: 2)),
        prefixIconColor: cs.onSurfaceVariant,
        suffixIconColor: cs.onSurfaceVariant,
        floatingLabelStyle: TextStyle(color: linkColor, fontWeight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: isDark ? cs.surfaceContainerLow : Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.amber,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.ink : cs.onSurfaceVariant)),
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? cs.onSurface : cs.onSurfaceVariant,
            )),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: isDark ? cs.surfaceContainerLow : Colors.white,
        indicatorColor: AppColors.amber,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selectedIconTheme: const IconThemeData(color: AppColors.ink),
        unselectedIconTheme: IconThemeData(color: cs.onSurfaceVariant),
        selectedLabelTextStyle: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface),
        unselectedLabelTextStyle: TextStyle(color: cs.onSurfaceVariant),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.amber,
          selectedForegroundColor: AppColors.ink,
          foregroundColor: cs.onSurface,
          side: BorderSide(color: cs.outlineVariant),
          shape: buttonShape,
          textStyle: text.labelLarge,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: cs.outlineVariant),
        selectedColor: AppColors.amber,
        checkmarkColor: AppColors.ink,
        labelStyle: text.labelMedium?.copyWith(color: cs.onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(color: AppColors.ink, fontWeight: FontWeight.w700),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.onSurface,
        unselectedLabelColor: cs.onSurfaceVariant,
        indicatorColor: cs.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: text.labelLarge,
        dividerColor: cs.outlineVariant,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: text.titleLarge?.copyWith(color: cs.onSurface),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.charcoal,
        contentTextStyle: const TextStyle(color: Colors.white),
        actionTextColor: AppColors.amber,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: cs.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: cs.primary, linearTrackColor: cs.surfaceContainerHighest, circularTrackColor: Colors.transparent),
      sliderTheme: base.sliderTheme.copyWith(activeTrackColor: cs.primary, thumbColor: cs.primary, inactiveTrackColor: cs.surfaceContainerHighest),
      badgeTheme: const BadgeThemeData(backgroundColor: AppColors.ember, textColor: Colors.white),
      dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 1),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.ink : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.amber : null),
      ),
    );
  }
}
