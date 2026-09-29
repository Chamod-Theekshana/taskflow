import 'package:flutter/material.dart';

/// Colour tokens of the "Obsidian Kinetic" design: deep charcoal surfaces
/// stacked in tonal tiers, with safety orange for anything active.
///
/// Read them with `context.palette`. A light variant with the same roles
/// backs the Light option of the theme switch.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  /// Page background.
  final Color canvas;

  /// Cards and panels (`#1a1c22`).
  final Color card;

  /// Tiles nested in cards, finished task cards (`#15171d`).
  final Color cardMuted;

  /// Deepest well: checkboxes, segmented control tracks (`#121316`).
  final Color well;

  /// Tags, secondary chips and buttons (`#22252e`).
  final Color raised;

  /// Progress tracks and counters (`#282b35`).
  final Color track;

  /// 1px structural borders (`#2a2d36`).
  final Color border;

  /// Very soft separators inside cards.
  final Color divider;

  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color textFaint;

  /// Warm secondary text of the sign-in screens (`#e2bfb0`).
  final Color warm;

  /// Warm muted text: field labels, hints (`#a98a7d`).
  final Color warmMuted;

  /// Safety orange.
  final Color accent;

  /// End colour of the orange gradients.
  final Color accentBright;

  /// Light orange used for text on orange-tinted backgrounds.
  final Color accentSoft;

  /// Medium priority.
  final Color peach;
  final Color peachTint;
  final Color peachText;

  /// Low priority strip and dot.
  final Color low;

  final Color success;
  final Color successTint;
  final Color successBorder;

  final Color danger;
  final Color amber;

  final Color dockTop;
  final Color dockBottom;

  /// Colour of the soft drop shadows under cards.
  final Color shadow;

  const AppPalette({
    required this.canvas,
    required this.card,
    required this.cardMuted,
    required this.well,
    required this.raised,
    required this.track,
    required this.border,
    required this.divider,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.warm,
    required this.warmMuted,
    required this.accent,
    required this.accentBright,
    required this.accentSoft,
    required this.peach,
    required this.peachTint,
    required this.peachText,
    required this.low,
    required this.success,
    required this.successTint,
    required this.successBorder,
    required this.danger,
    required this.amber,
    required this.dockTop,
    required this.dockBottom,
    required this.shadow,
  });

  static const dark = AppPalette(
    canvas: Color(0xFF0E0F12),
    card: Color(0xFF1A1C22),
    cardMuted: Color(0xFF15171D),
    well: Color(0xFF121316),
    raised: Color(0xFF22252E),
    track: Color(0xFF282B35),
    border: Color(0xFF2A2D36),
    divider: Color(0x0FFFFFFF),
    text: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9CA3AF),
    textMuted: Color(0xFF6B7280),
    textFaint: Color(0xFF4B5563),
    warm: Color(0xFFE2BFB0),
    warmMuted: Color(0xFFA98A7D),
    accent: Color(0xFFFF6B00),
    accentBright: Color(0xFFFF8533),
    accentSoft: Color(0xFFFFB693),
    peach: Color(0xFFFFB77D),
    peachTint: Color(0xFF2A1E17),
    peachText: Color(0xFFFFDCC3),
    low: Color(0xFF4A4E5A),
    success: Color(0xFF34D399),
    successTint: Color(0xFF102A1B),
    successBorder: Color(0xFF1E4A30),
    danger: Color(0xFFFB7185),
    amber: Color(0xFFF59E0B),
    dockTop: Color(0xFF1E2129),
    dockBottom: Color(0xFF14161C),
    shadow: Color(0x66000000),
  );

  static const light = AppPalette(
    canvas: Color(0xFFF4F5F7),
    card: Color(0xFFFFFFFF),
    cardMuted: Color(0xFFF3F4F6),
    well: Color(0xFFF1F2F5),
    raised: Color(0xFFEEF0F3),
    track: Color(0xFFE4E7EC),
    border: Color(0xFFE2E4EA),
    divider: Color(0x0F000000),
    text: Color(0xFF111318),
    textSecondary: Color(0xFF5B6270),
    textMuted: Color(0xFF8A919E),
    textFaint: Color(0xFFB4BAC4),
    warm: Color(0xFF7A4E3A),
    warmMuted: Color(0xFF9C7564),
    accent: Color(0xFFFF6B00),
    accentBright: Color(0xFFFF8533),
    accentSoft: Color(0xFFC2410C),
    peach: Color(0xFFF29A4A),
    peachTint: Color(0xFFFFF1E6),
    peachText: Color(0xFF9A4A00),
    low: Color(0xFFB8BEC8),
    success: Color(0xFF059669),
    successTint: Color(0xFFE7F8F0),
    successBorder: Color(0xFFBBEBD5),
    danger: Color(0xFFE11D48),
    amber: Color(0xFFD97706),
    dockTop: Color(0xFFFFFFFF),
    dockBottom: Color(0xFFF3F4F6),
    shadow: Color(0x14000000),
  );

  /// Primary buttons and the active dock disc: orange, brightening to the
  /// right.
  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [accent, accentBright],
  );

  /// Orange halo behind active elements (removed).
  List<BoxShadow> glow([double strength = 1]) => const [];

  /// Soft drop shadow under cards (`shadow-lg shadow-black/40`).
  List<BoxShadow> get cardShadow => [
    BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8)),
  ];

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? card,
    Color? cardMuted,
    Color? well,
    Color? raised,
    Color? track,
    Color? border,
    Color? divider,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? warm,
    Color? warmMuted,
    Color? accent,
    Color? accentBright,
    Color? accentSoft,
    Color? peach,
    Color? peachTint,
    Color? peachText,
    Color? low,
    Color? success,
    Color? successTint,
    Color? successBorder,
    Color? danger,
    Color? amber,
    Color? dockTop,
    Color? dockBottom,
    Color? shadow,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      card: card ?? this.card,
      cardMuted: cardMuted ?? this.cardMuted,
      well: well ?? this.well,
      raised: raised ?? this.raised,
      track: track ?? this.track,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      textFaint: textFaint ?? this.textFaint,
      warm: warm ?? this.warm,
      warmMuted: warmMuted ?? this.warmMuted,
      accent: accent ?? this.accent,
      accentBright: accentBright ?? this.accentBright,
      accentSoft: accentSoft ?? this.accentSoft,
      peach: peach ?? this.peach,
      peachTint: peachTint ?? this.peachTint,
      peachText: peachText ?? this.peachText,
      low: low ?? this.low,
      success: success ?? this.success,
      successTint: successTint ?? this.successTint,
      successBorder: successBorder ?? this.successBorder,
      danger: danger ?? this.danger,
      amber: amber ?? this.amber,
      dockTop: dockTop ?? this.dockTop,
      dockBottom: dockBottom ?? this.dockBottom,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      canvas: mix(canvas, other.canvas),
      card: mix(card, other.card),
      cardMuted: mix(cardMuted, other.cardMuted),
      well: mix(well, other.well),
      raised: mix(raised, other.raised),
      track: mix(track, other.track),
      border: mix(border, other.border),
      divider: mix(divider, other.divider),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      textFaint: mix(textFaint, other.textFaint),
      warm: mix(warm, other.warm),
      warmMuted: mix(warmMuted, other.warmMuted),
      accent: mix(accent, other.accent),
      accentBright: mix(accentBright, other.accentBright),
      accentSoft: mix(accentSoft, other.accentSoft),
      peach: mix(peach, other.peach),
      peachTint: mix(peachTint, other.peachTint),
      peachText: mix(peachText, other.peachText),
      low: mix(low, other.low),
      success: mix(success, other.success),
      successTint: mix(successTint, other.successTint),
      successBorder: mix(successBorder, other.successBorder),
      danger: mix(danger, other.danger),
      amber: mix(amber, other.amber),
      dockTop: mix(dockTop, other.dockTop),
      dockBottom: mix(dockBottom, other.dockBottom),
      shadow: mix(shadow, other.shadow),
    );
  }
}

/// Brand colours that don't change with the theme.
abstract final class AppColors {
  static const orange = Color(0xFFFF6B00);

  /// The app icon tile: bright orange at the top left, deeper at the bottom
  /// right.
  static const logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8A1F), Color(0xFFFF6B00), Color(0xFFE84F00)],
  );
}
