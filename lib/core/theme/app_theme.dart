import 'package:flutter/material.dart';

import 'app_colors.dart';

export 'app_colors.dart';

abstract final class AppFonts {
  static const heading = 'PlusJakartaSans';
  static const body = 'Inter';
}

abstract final class AppTheme {
  static final ThemeData light = _build(_light);
  static final ThemeData dark = _build(_dark);

  static const ColorScheme _light = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: Color(0xFFFFFBFF),
    primaryFixed: AppColors.primaryFixed,
    primaryFixedDim: AppColors.primaryFixedDim,
    onPrimaryFixed: AppColors.onPrimaryFixed,
    onPrimaryFixedVariant: AppColors.onPrimaryFixedVariant,
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    secondaryFixed: AppColors.secondaryFixed,
    secondaryFixedDim: AppColors.secondaryFixedDim,
    onSecondaryFixed: AppColors.onSecondaryFixed,
    onSecondaryFixedVariant: AppColors.onSecondaryFixedVariant,
    tertiary: AppColors.tertiary,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: Color(0xFFFFFBFF),
    tertiaryFixed: AppColors.tertiaryFixed,
    tertiaryFixedDim: AppColors.tertiaryFixedDim,
    onTertiaryFixed: AppColors.onTertiaryFixed,
    onTertiaryFixedVariant: AppColors.onTertiaryFixedVariant,
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    surfaceDim: AppColors.surfaceDim,
    surfaceBright: AppColors.surface,
    surfaceContainerLowest: AppColors.surfaceLowest,
    surfaceContainerLow: AppColors.surfaceLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceHigh,
    surfaceContainerHighest: AppColors.surfaceHighest,
    onSurfaceVariant: AppColors.onSurfaceVariant,
    outline: AppColors.outline,
    outlineVariant: AppColors.outlineVariant,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.inverseSurface,
    onInverseSurface: AppColors.inverseOnSurface,
    inversePrimary: AppColors.primaryFixedDim,
    surfaceTint: AppColors.primary,
  );

  // Night version of the same palette. The "fixed" roles are used for soft
  // chips and badges, so they get dark tones here instead of staying pastel.
  static const ColorScheme _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFC0C1FF),
    onPrimary: Color(0xFF1000A9),
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: Colors.white,
    primaryFixed: Color(0xFF2A2B8F),
    primaryFixedDim: Color(0xFF3A3BB0),
    onPrimaryFixed: Color(0xFFE1E0FF),
    onPrimaryFixedVariant: Color(0xFFC0C1FF),
    secondary: Color(0xFF4EDEA3),
    onSecondary: Color(0xFF003824),
    secondaryContainer: Color(0xFF005236),
    onSecondaryContainer: Color(0xFF6FFBBE),
    secondaryFixed: Color(0xFF00462E),
    secondaryFixedDim: Color(0xFF006C49),
    onSecondaryFixed: Color(0xFF6FFBBE),
    onSecondaryFixedVariant: Color(0xFF4EDEA3),
    tertiary: Color(0xFFFFB95F),
    onTertiary: Color(0xFF462A00),
    tertiaryContainer: Color(0xFFA36700),
    onTertiaryContainer: Colors.white,
    tertiaryFixed: Color(0xFF4F3000),
    tertiaryFixedDim: Color(0xFF825100),
    onTertiaryFixed: Color(0xFFFFDDB8),
    onTertiaryFixedVariant: Color(0xFFFFB95F),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF11131C),
    onSurface: Color(0xFFE2E5F7),
    surfaceDim: Color(0xFF11131C),
    surfaceBright: Color(0xFF363947),
    surfaceContainerLowest: Color(0xFF1A1D2A),
    surfaceContainerLow: Color(0xFF161925),
    surfaceContainer: Color(0xFF222636),
    surfaceContainerHigh: Color(0xFF2A2E3F),
    surfaceContainerHighest: Color(0xFF34394B),
    onSurfaceVariant: Color(0xFFC7C4D7),
    outline: Color(0xFF918FA3),
    outlineVariant: Color(0xFF464554),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFE2E5F7),
    onInverseSurface: Color(0xFF283044),
    inversePrimary: AppColors.primary,
    surfaceTint: Color(0xFFC0C1FF),
  );

  static TextTheme _textTheme(Color color) {
    TextStyle style(
      String family,
      double size,
      double lineHeight,
      FontWeight weight, [
      double tracking = 0,
    ]) {
      return TextStyle(
        fontFamily: family,
        fontSize: size,
        height: lineHeight / size,
        fontWeight: weight,
        letterSpacing: tracking * size,
        color: color,
      );
    }

    const h = AppFonts.heading;
    const b = AppFonts.body;
    return TextTheme(
      displayLarge: style(h, 32, 40, FontWeight.w700, -0.02),
      displayMedium: style(h, 26, 34, FontWeight.w700, -0.02),
      displaySmall: style(h, 22, 28, FontWeight.w700, -0.015),
      headlineLarge: style(h, 22, 28, FontWeight.w600, -0.015),
      headlineMedium: style(h, 18, 24, FontWeight.w600, -0.01),
      headlineSmall: style(h, 16, 22, FontWeight.w600),
      titleLarge: style(h, 22, 28, FontWeight.w600, -0.015),
      titleMedium: style(h, 16, 22, FontWeight.w600),
      titleSmall: style(h, 14, 20, FontWeight.w600),
      bodyLarge: style(b, 16, 24, FontWeight.w400),
      bodyMedium: style(b, 14, 20, FontWeight.w400),
      bodySmall: style(b, 13, 18, FontWeight.w400),
      labelLarge: style(h, 14, 20, FontWeight.w600),
      labelMedium: style(h, 12, 16, FontWeight.w600, 0.01),
      labelSmall: style(h, 11, 14, FontWeight.w500, 0.02),
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    final text = _textTheme(scheme.onSurface);
    final rounded16 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      fontFamily: AppFonts.body,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      dividerColor: scheme.outlineVariant.withValues(alpha: 0.5),
      appBarTheme: AppBarThemeData(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.headlineMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.labelLarge?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: rounded16,
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: text.headlineMedium,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: rounded16,
        textStyle: text.labelLarge,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: text.bodyMedium?.copyWith(color: scheme.outline),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: text.labelLarge,
          shape: const StadiumBorder(),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: text.labelLarge,
          minimumSize: const Size(64, 48),
          shape: rounded16,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: text.labelSmall?.copyWith(color: scheme.onInverseSurface),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}

extension ThemeLookup on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}
