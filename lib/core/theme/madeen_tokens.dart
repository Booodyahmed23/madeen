import 'package:flutter/material.dart';

/// MADEEN design tokens — the Stitch "Charter & Metric" system (see the
/// design package's DESIGN.md): an editorial, Swiss-rationalist palette of
/// Oxford slate ink, burnished ochre accent and warm alabaster stone, with
/// an intentional (not inverted) "Executive Obsidian" dark mode.
///
/// Exposed as a [ThemeExtension] so every widget reads colors from the
/// active theme (`MadeenTokens.of(context)`) and light/dark switch for
/// free. Spacing, radii and type live in [MadeenSpace], [MadeenRadius] and
/// `madeen_typography.dart` — they don't vary by brightness.
@immutable
class MadeenTokens extends ThemeExtension<MadeenTokens> {
  const MadeenTokens({
    required this.canvas,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.neutralFill,
    required this.hairline,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.accent,
    required this.accentText,
    required this.primaryAction,
    required this.onPrimaryAction,
    required this.hero,
    required this.heroBorder,
    required this.onHero,
    required this.onHeroMuted,
    required this.heroAccent,
    required this.success,
    required this.attention,
    required this.error,
  });

  /// Level 0 — the flat page floor.
  final Color canvas;

  /// Level 1 — cards and panels, always bounded by [hairline].
  final Color surface;

  /// Level 2 — controls resting on a surface (selected segments, sheets).
  final Color surfaceElevated;

  /// A recessed panel tone (e.g. the AI insight card) — quieter than
  /// [surface], never a different hue.
  final Color surfaceMuted;

  /// Subtle fills inside a card: metric tiles, icon wells, tags.
  final Color neutralFill;

  /// The single 1px architectural divider/border color.
  final Color hairline;

  /// Primary text, headings, metrics.
  final Color ink;

  /// Metadata and secondary body copy.
  final Color inkSecondary;

  /// Minor labels, timestamps, inactive states.
  final Color inkTertiary;

  /// Burnished ochre / antique brass — fills, borders, active markers.
  final Color accent;

  /// [accent] tuned for *text* contrast (ochre on white is too light for
  /// small type in light mode).
  final Color accentText;

  /// The solid primary trigger (Start Studying).
  final Color primaryAction;
  final Color onPrimaryAction;

  /// The deep Oxford-slate hero panel.
  final Color hero;
  final Color heroBorder;
  final Color onHero;
  final Color onHeroMuted;
  final Color heroAccent;

  final Color success;
  final Color attention;
  final Color error;

  static const light = MadeenTokens(
    canvas: Color(0xFFFBFBF9),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFFFFFFF),
    surfaceMuted: Color(0xFFEEEEEC),
    neutralFill: Color(0xFFF3F3EE),
    hairline: Color(0xFFE5E5DF),
    ink: Color(0xFF0F172A),
    inkSecondary: Color(0xFF475569),
    inkTertiary: Color(0xFF94A3B8),
    accent: Color(0xFFC28E3A),
    accentText: Color(0xFF805600),
    primaryAction: Color(0xFF0F172A),
    onPrimaryAction: Color(0xFFFFFFFF),
    hero: Color(0xFF131B2E),
    heroBorder: Color(0xFF131B2E),
    onHero: Color(0xFFFFFFFF),
    onHeroMuted: Color(0xFFBEC6E0),
    heroAccent: Color(0xFFF6BC63),
    success: Color(0xFF2D6A4F),
    attention: Color(0xFFB45309),
    error: Color(0xFFBA1A1A),
  );

  static const dark = MadeenTokens(
    canvas: Color(0xFF0C0E12),
    surface: Color(0xFF151922),
    surfaceElevated: Color(0xFF1E2330),
    surfaceMuted: Color(0xFF181D26),
    // DESIGN.md "Neutral Accent Fill" (dark).
    neutralFill: Color(0xFF181D26),
    hairline: Color(0xFF262D3D),
    ink: Color(0xFFF1F5F9),
    inkSecondary: Color(0xFF94A3B8),
    inkTertiary: Color(0xFF64748B),
    accent: Color(0xFFD4A359),
    accentText: Color(0xFFD4A359),
    primaryAction: Color(0xFFD4A359),
    onPrimaryAction: Color(0xFF0C0E12),
    hero: Color(0xFF1E2330),
    heroBorder: Color(0xFF333C4D),
    onHero: Color(0xFFF1F5F9),
    onHeroMuted: Color(0xFF94A3B8),
    heroAccent: Color(0xFFD4A359),
    success: Color(0xFF40916C),
    attention: Color(0xFFE08A3C),
    error: Color(0xFFFFB4AB),
  );

  /// The tokens of the nearest theme — falls back to the brightness-matched
  /// defaults, so a widget never fails just because it was pumped under a
  /// theme without the extension (e.g. a bare test MaterialApp).
  static MadeenTokens of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<MadeenTokens>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  MadeenTokens copyWith() => this;

  @override
  MadeenTokens lerp(ThemeExtension<MadeenTokens>? other, double t) {
    if (other is! MadeenTokens) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return MadeenTokens(
      canvas: mix(canvas, other.canvas),
      surface: mix(surface, other.surface),
      surfaceElevated: mix(surfaceElevated, other.surfaceElevated),
      surfaceMuted: mix(surfaceMuted, other.surfaceMuted),
      neutralFill: mix(neutralFill, other.neutralFill),
      hairline: mix(hairline, other.hairline),
      ink: mix(ink, other.ink),
      inkSecondary: mix(inkSecondary, other.inkSecondary),
      inkTertiary: mix(inkTertiary, other.inkTertiary),
      accent: mix(accent, other.accent),
      accentText: mix(accentText, other.accentText),
      primaryAction: mix(primaryAction, other.primaryAction),
      onPrimaryAction: mix(onPrimaryAction, other.onPrimaryAction),
      hero: mix(hero, other.hero),
      heroBorder: mix(heroBorder, other.heroBorder),
      onHero: mix(onHero, other.onHero),
      onHeroMuted: mix(onHeroMuted, other.onHeroMuted),
      heroAccent: mix(heroAccent, other.heroAccent),
      success: mix(success, other.success),
      attention: mix(attention, other.attention),
      error: mix(error, other.error),
    );
  }
}

/// The 8pt-derived spacing scale (DESIGN.md "spacing").
abstract final class MadeenSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal page gutter on phones.
  static const double pageMargin = 20;
}

/// Crisp, restrained corner radii (DESIGN.md "rounded").
abstract final class MadeenRadius {
  /// Buttons, metric tiles, inner blocks — "crisp print document" corners.
  static const double base = 4;

  /// Cards / monolithic panels (the reference screen's card corners).
  static const double card = 8;

  /// Pills: segmented controls, micro-tags, status chips.
  static const double pill = 999;
}

/// Component sizing shared across the system.
abstract final class MadeenSize {
  /// Primary/secondary trigger height (DESIGN.md "48px height").
  static const double buttonHeight = 48;

  /// Square icon wells in list rows and tiles.
  static const double iconWell = 36;

  /// The 1px hairline.
  static const double hairline = 1;
}
