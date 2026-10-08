import 'package:flutter/material.dart';

/// MADEEN type scale (DESIGN.md "typography"): **Newsreader** for the
/// editorial voice (page and card headings), **Hanken Grotesk** for every
/// operational element (body, labels, metrics, buttons, navigation).
///
/// Both families are bundled Latin-only (pubspec.yaml); Arabic glyphs fall
/// back to the platform's Arabic font automatically, so these styles stay
/// readable in RTL without a separate Arabic scale.
///
/// Colors are deliberately absent — callers apply a [MadeenTokens] ink so
/// the same style works in light and dark.
abstract final class MadeenType {
  static const serif = 'Newsreader';
  static const sans = 'HankenGrotesk';

  /// Tabular figures — numbers never jump as metrics/timers change.
  static const _tabular = [FontFeature.tabularFigures()];

  // Editorial (Newsreader)
  static const displayHero = TextStyle(
    fontFamily: serif,
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.48,
  );
  static const headlineLg = TextStyle(
    fontFamily: serif,
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.28,
  );
  static const headlineMd = TextStyle(
    fontFamily: serif,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w500,
  );
  static const headlineSm = TextStyle(
    fontFamily: serif,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  );

  // Operational (Hanken Grotesk)
  static const bodyLg = TextStyle(
    fontFamily: sans,
    fontSize: 17,
    height: 26 / 17,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.085,
  );

  /// Question / problem statements (DESIGN.md: operational grotesque, not
  /// the editorial serif) — a touch larger and medium weight for
  /// sustained reading under exam conditions.
  static const question = TextStyle(
    fontFamily: sans,
    fontSize: 18,
    height: 27 / 18,
    fontWeight: FontWeight.w500,
  );
  static const bodyMd = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 22 / 15,
    fontWeight: FontWeight.w400,
  );
  static const bodySm = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    height: 18 / 13,
    fontWeight: FontWeight.w400,
  );
  static const metricLg = TextStyle(
    fontFamily: sans,
    fontSize: 32,
    height: 36 / 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.64,
    fontFeatures: _tabular,
  );

  /// Hero figures — a session/exam score.
  static const metricXl = TextStyle(
    fontFamily: sans,
    fontSize: 48,
    height: 52 / 48,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.96,
    fontFeatures: _tabular,
  );
  static const metricMd = TextStyle(
    fontFamily: sans,
    fontSize: 20,
    height: 24 / 20,
    fontWeight: FontWeight.w600,
    fontFeatures: _tabular,
  );

  /// Section eyebrows ("PERFORMANCE SNAPSHOT") — pass upper-cased text.
  static const labelCaps = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.88,
  );

  /// [labelCaps] adjusted per script: Arabic is a connected script with no
  /// upper case, so letter-spacing would pull its joined letters apart and
  /// 11px is too small for it — Arabic eyebrows get no tracking, a slightly
  /// larger size, and a taller line.
  static TextStyle eyebrow(BuildContext context) {
    if (Localizations.localeOf(context).languageCode != 'ar') return labelCaps;
    return labelCaps.copyWith(
      fontSize: 12.5,
      height: 18 / 12.5,
      fontWeight: FontWeight.w600,
      letterSpacing: 0,
    );
  }

  static const labelMd = TextStyle(
    fontFamily: sans,
    fontSize: 13,
    height: 16 / 13,
    fontWeight: FontWeight.w500,
  );
  static const labelSm = TextStyle(
    fontFamily: sans,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w600,
  );
  static const button = TextStyle(
    fontFamily: sans,
    fontSize: 15,
    height: 20 / 15,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  /// The Material [TextTheme] built from this scale, so stock Material
  /// widgets inside a MADEEN-themed screen (dialogs, list tiles, buttons)
  /// pick up the same families.
  ///
  /// [arabic] drops every letter-spacing value: Arabic is a connected
  /// script, and tracking (positive or negative) breaks its joins.
  static TextTheme textTheme(
    Color ink,
    Color inkSecondary, {
    bool arabic = false,
  }) {
    TextStyle c(TextStyle s, [Color? color]) =>
        s.copyWith(color: color ?? ink, letterSpacing: arabic ? 0 : null);
    return TextTheme(
      displayLarge: c(displayHero),
      // Used by the app for single hero figures (scores), so it is a
      // tabular grotesque metric, not an editorial serif.
      displayMedium: c(metricXl),
      displaySmall: c(headlineLg),
      headlineLarge: c(headlineLg),
      headlineMedium: c(headlineMd),
      headlineSmall: c(headlineMd),
      titleLarge: c(headlineSm),
      titleMedium: c(bodyMd.copyWith(fontWeight: FontWeight.w600)),
      titleSmall: c(labelMd.copyWith(fontWeight: FontWeight.w600)),
      bodyLarge: c(bodyLg),
      bodyMedium: c(bodyMd),
      bodySmall: c(bodySm, inkSecondary),
      labelLarge: c(button),
      labelMedium: c(labelMd),
      labelSmall: c(labelSm, inkSecondary),
    );
  }
}
