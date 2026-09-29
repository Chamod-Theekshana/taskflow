import 'package:flutter/material.dart';

import 'app_colors.dart';

export 'app_colors.dart';

abstract final class AppFonts {
  /// Headlines and body copy.
  static const sans = 'Geist';

  /// Labels, badges, numbers and other "telemetry".
  static const mono = 'JetBrainsMono';
}

abstract final class AppTheme {
  static final ThemeData dark = _build(Brightness.dark, AppPalette.dark);
  static final ThemeData light = _build(Brightness.light, AppPalette.light);

  static ColorScheme _scheme(Brightness brightness, AppPalette p) {
    final isDark = brightness == Brightness.dark;
    return ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: Colors.white,
      primaryContainer: p.accent.withValues(alpha: isDark ? 0.2 : 0.14),
      onPrimaryContainer: p.accentSoft,
      secondary: p.accentBright,
      onSecondary: Colors.white,
      secondaryContainer: p.peachTint,
      onSecondaryContainer: p.peachText,
      tertiary: p.peach,
      onTertiary: isDark ? const Color(0xFF4D2600) : Colors.white,
      error: p.danger,
      onError: Colors.white,
      errorContainer: isDark ? const Color(0xFF3D1314) : const Color(0xFFFFE4E8),
      onErrorContainer: isDark ? const Color(0xFFFFB4AB) : const Color(0xFF9F1239),
      surface: p.canvas,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerLowest: p.well,
      surfaceContainerLow: p.cardMuted,
      surfaceContainer: p.card,
      surfaceContainerHigh: p.card,
      surfaceContainerHighest: p.raised,
      outline: p.low,
      outlineVariant: p.border,
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? const Color(0xFFE2E2E9) : const Color(0xFF1A1C22),
      onInverseSurface: isDark ? const Color(0xFF111318) : Colors.white,
      inversePrimary: p.accentBright,
      surfaceTint: Colors.transparent,
    );
  }

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

    const s = AppFonts.sans;
    const m = AppFonts.mono;
    return TextTheme(
      displayLarge: style(s, 32, 40, FontWeight.w700, -0.02),
      displayMedium: style(s, 26, 34, FontWeight.w700, -0.02),
      displaySmall: style(s, 22, 28, FontWeight.w700, -0.015),
      headlineLarge: style(s, 22, 28, FontWeight.w600, -0.015),
      headlineMedium: style(s, 18, 24, FontWeight.w600, -0.01),
      headlineSmall: style(s, 16, 22, FontWeight.w600, -0.005),
      titleLarge: style(s, 20, 28, FontWeight.w600, -0.01),
      titleMedium: style(s, 16, 22, FontWeight.w600),
      titleSmall: style(s, 14, 20, FontWeight.w600),
      bodyLarge: style(s, 16, 24, FontWeight.w400),
      bodyMedium: style(s, 14, 20, FontWeight.w400),
      bodySmall: style(s, 13, 18, FontWeight.w400),
      labelLarge: style(m, 14, 20, FontWeight.w600),
      labelMedium: style(m, 12, 16, FontWeight.w600, 0.01),
      labelSmall: style(m, 11, 14, FontWeight.w500, 0.02),
    );
  }

  static ThemeData _build(Brightness brightness, AppPalette p) {
    final scheme = _scheme(brightness, p);
    final text = _textTheme(p.text);
    const buttonText = TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: 14,
      fontWeight: FontWeight.w600,
    );
    final panelShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: p.border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [p],
      fontFamily: AppFonts.sans,
      textTheme: text,
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      dividerColor: p.border,
      appBarTheme: AppBarThemeData(
        backgroundColor: p.canvas,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: text.headlineMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.raised,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.text),
        actionTextColor: p.accent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
        elevation: 0,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        shape: panelShape,
        titleTextStyle: text.headlineMedium,
        contentTextStyle: text.bodyMedium?.copyWith(color: p.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.track,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          side: BorderSide(color: p.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
        textStyle: text.bodyMedium,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.card,
        headerForegroundColor: p.text,
        shape: panelShape,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.card,
        dialBackgroundColor: p.raised,
        shape: panelShape,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: p.well,
        hintStyle: text.bodyMedium?.copyWith(color: p.textMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p.accent),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.accent,
        selectionColor: p.accent.withValues(alpha: 0.3),
        selectionHandleColor: p.accent,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          textStyle: buttonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: Colors.white,
          textStyle: buttonText,
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconTheme: IconThemeData(color: p.textSecondary),
      listTileTheme: ListTileThemeData(
        iconColor: p.textSecondary,
        textColor: p.text,
        selectedColor: p.accent,
        selectedTileColor: p.accent.withValues(alpha: 0.12),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.raised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.border),
        ),
        textStyle: text.labelSmall?.copyWith(color: p.text),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    );
  }
}

extension ThemeLookup on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// Design tokens of the current theme.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ??
      (isDark ? AppPalette.dark : AppPalette.light);
}
