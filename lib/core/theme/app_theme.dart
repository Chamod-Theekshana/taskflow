import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

export 'app_colors.dart';
export 'app_typography.dart';

class AppTheme {
  AppTheme._();

  /// Built once instead of on every rebuild of the app widget.
  static final ThemeData lightTheme = _build(_lightScheme);
  static final ThemeData darkTheme = _build(_darkScheme);

  /// The screens use the Material 3 "fixed" and "surface container" roles
  /// (`primaryFixed`, `tertiaryFixed`, `surfaceContainerLow`, ...). They were
  /// not set before, so Flutter fell back to `primary` / `tertiary` /
  /// `surface`: selected category chips, the medium-priority option and the
  /// reminder icon rendered primary-on-primary (invisible), and every card,
  /// search bar and pill blended into the background.
  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: Colors.white,
    primaryFixed: AppColors.primaryFixed,
    primaryFixedDim: AppColors.primaryFixedDim,
    onPrimaryFixed: AppColors.onPrimaryFixed,
    onPrimaryFixedVariant: AppColors.onPrimaryFixedVariant,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    onSecondaryContainer: AppColors.onSecondaryContainer,
    secondaryFixed: AppColors.secondaryFixed,
    onSecondaryFixed: AppColors.onSecondaryContainer,
    tertiary: AppColors.tertiary,
    onTertiary: AppColors.onTertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    onTertiaryContainer: Colors.white,
    tertiaryFixed: AppColors.tertiaryFixed,
    tertiaryFixedDim: AppColors.tertiaryFixedDim,
    onTertiaryFixed: AppColors.onTertiaryFixed,
    onTertiaryFixedVariant: AppColors.tertiary,
    error: AppColors.error,
    onError: AppColors.onError,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.onSurface,
    surfaceDim: AppColors.surfaceDim,
    surfaceBright: AppColors.surfaceContainerLowest,
    surfaceContainerLowest: AppColors.surfaceContainerLowest,
    surfaceContainerLow: AppColors.surfaceContainerLow,
    surfaceContainer: AppColors.surfaceContainer,
    surfaceContainerHigh: AppColors.surfaceContainerHigh,
    surfaceContainerHighest: AppColors.surfaceContainerHighest,
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

  /// Full tonal dark palette generated from the brand colour (the previous
  /// dark theme only set three colours and dropped the app fonts).
  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  );

  static TextTheme _textTheme(Color color) => TextTheme(
    displayLarge: AppTypography.displayLg,
    displayMedium: AppTypography.displayLgMobile,
    headlineLarge: AppTypography.headlineLg,
    headlineMedium: AppTypography.headlineMd,
    headlineSmall: AppTypography.headlineSm,
    titleLarge: AppTypography.headlineLg,
    titleMedium: AppTypography.headlineSm,
    titleSmall: AppTypography.labelLg,
    bodyLarge: AppTypography.bodyLg,
    bodyMedium: AppTypography.bodyMd,
    bodySmall: AppTypography.bodySm,
    labelLarge: AppTypography.labelLg,
    labelMedium: AppTypography.labelMd,
    labelSmall: AppTypography.labelSm,
  ).apply(bodyColor: color, displayColor: color);

  static ThemeData _build(ColorScheme scheme) {
    final textTheme = _textTheme(scheme.onSurface);
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineMedium,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
