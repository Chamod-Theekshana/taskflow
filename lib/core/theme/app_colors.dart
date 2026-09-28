import 'package:flutter/material.dart';

/// Colours from the "Serene Focus" design system.
abstract final class AppColors {
  static const primary = Color(0xFF4648D4);
  static const primaryContainer = Color(0xFF6063EE);
  static const indigo = Color(0xFF6366F1);
  static const indigoDeep = Color(0xFF4F46E5);

  static const surface = Color(0xFFFAF8FF);
  static const surfaceDim = Color(0xFFD2D9F4);
  static const surfaceLowest = Color(0xFFFFFFFF);
  static const surfaceLow = Color(0xFFF2F3FF);
  static const surfaceContainer = Color(0xFFEAEDFF);
  static const surfaceHigh = Color(0xFFE2E7FF);
  static const surfaceHighest = Color(0xFFDAE2FD);
  static const onSurface = Color(0xFF131B2E);
  static const onSurfaceVariant = Color(0xFF464554);
  static const outline = Color(0xFF767586);
  static const outlineVariant = Color(0xFFC7C4D7);

  static const primaryFixed = Color(0xFFE1E0FF);
  static const primaryFixedDim = Color(0xFFC0C1FF);
  static const onPrimaryFixed = Color(0xFF07006C);
  static const onPrimaryFixedVariant = Color(0xFF2F2EBE);

  static const secondary = Color(0xFF006C49);
  static const secondaryContainer = Color(0xFF6CF8BB);
  static const onSecondaryContainer = Color(0xFF00714D);
  static const secondaryFixed = Color(0xFF6FFBBE);
  static const secondaryFixedDim = Color(0xFF4EDEA3);
  static const onSecondaryFixed = Color(0xFF002113);
  static const onSecondaryFixedVariant = Color(0xFF005236);

  static const tertiary = Color(0xFF825100);
  static const tertiaryContainer = Color(0xFFA36700);
  static const tertiaryFixed = Color(0xFFFFDDB8);
  static const tertiaryFixedDim = Color(0xFFFFB95F);
  static const onTertiaryFixed = Color(0xFF2A1700);
  static const onTertiaryFixedVariant = Color(0xFF653E00);

  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const onErrorContainer = Color(0xFF93000A);

  static const inverseSurface = Color(0xFF283044);
  static const inverseOnSurface = Color(0xFFEEF0FF);

  /// The app icon tile (`from-primary to-primary-container`, bottom-left to
  /// top-right).
  static const logoGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [primary, primaryContainer],
  );

  /// The floating navigation dock.
  static const dockGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigoDeep, indigo],
  );
}

/// Soft, slate-tinted shadows used by cards and floating controls.
abstract final class AppShadows {
  static const sm = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const md = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 6,
      spreadRadius: -1,
      offset: Offset(0, 4),
    ),
  ];

  static const card = [
    BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 2)),
  ];

  static const header = [
    BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 1)),
  ];

  static const fab = [
    BoxShadow(
      color: Color(0x596366F1),
      blurRadius: 24,
      spreadRadius: -6,
      offset: Offset(0, 12),
    ),
  ];

  static const button = [
    BoxShadow(
      color: Color(0x404648D4),
      blurRadius: 15,
      spreadRadius: -3,
      offset: Offset(0, 10),
    ),
  ];
}
