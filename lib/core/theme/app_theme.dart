import 'package:flutter/material.dart';

import 'madeen_tokens.dart';
import 'madeen_typography.dart';

/// The app's themes: the MADEEN design system (`madeen_tokens.dart`,
/// `madeen_typography.dart`), in an intentional light and dark variant —
/// applied app-wide since Phase 14B (see app/app.dart).
class AppTheme {
  const AppTheme._();

  static ThemeData get madeenLight =>
      _madeenFrom(MadeenTokens.light, Brightness.light);

  static ThemeData get madeenDark =>
      _madeenFrom(MadeenTokens.dark, Brightness.dark);

  /// The MADEEN theme matching [brightness]; [arabic] selects the
  /// tracking-free text styles for Arabic (see MadeenType.textTheme).
  static ThemeData madeenFor(Brightness brightness, {bool arabic = false}) =>
      _madeenFrom(
        brightness == Brightness.dark ? MadeenTokens.dark : MadeenTokens.light,
        brightness,
        arabic: arabic,
      );

  /// `MaterialApp.builder`: re-themes everything below the app (every
  /// route, dialog and sheet) for the *resolved* locale, so Arabic gets the
  /// tracking-free text styles even when the locale comes from the system.
  static Widget localeAwareBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: madeenFor(
        Theme.of(context).brightness,
        arabic: Localizations.localeOf(context).languageCode == 'ar',
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  static OutlineInputBorder _box(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(MadeenRadius.base),
        borderSide: BorderSide(color: color, width: width),
      );

  static ThemeData _madeenFrom(
    MadeenTokens t,
    Brightness brightness, {
    bool arabic = false,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.primaryAction,
      onPrimary: t.onPrimaryAction,
      primaryContainer: t.hero,
      onPrimaryContainer: t.onHero,
      secondary: t.accent,
      onSecondary: t.onPrimaryAction,
      secondaryContainer: t.neutralFill,
      onSecondaryContainer: t.accentText,
      tertiary: t.success,
      onTertiary: t.surface,
      error: t.error,
      onError: t.surface,
      errorContainer: t.error.withValues(alpha: 0.12),
      onErrorContainer: t.error,
      surface: t.canvas,
      onSurface: t.ink,
      onSurfaceVariant: t.inkSecondary,
      surfaceContainerLowest: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainer: t.surface,
      surfaceContainerHigh: t.surfaceElevated,
      surfaceContainerHighest: t.neutralFill,
      outline: t.inkTertiary,
      outlineVariant: t.hairline,
      inverseSurface: t.ink,
      onInverseSurface: t.canvas,
      inversePrimary: t.accent,
      shadow: t.ink,
      scrim: t.ink,
      surfaceTint: Colors.transparent,
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(MadeenRadius.base),
    );
    // Arabic is a connected script: tracking would pull its joins apart.
    final buttonText = arabic
        ? MadeenType.button.copyWith(letterSpacing: 0)
        : MadeenType.button;
    final textTheme = MadeenType.textTheme(
      t.ink,
      t.inkSecondary,
      arabic: arabic,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.canvas,
      fontFamily: MadeenType.sans,
      textTheme: textTheme,
      dividerTheme: DividerThemeData(
        color: t.hairline,
        thickness: MadeenSize.hairline,
        space: MadeenSize.hairline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: t.canvas,
        foregroundColor: t.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: MadeenType.headlineMd.copyWith(color: t.ink),
        // A single hairline under every app bar — the architectural rule
        // that separates chrome from content (DESIGN.md "Dividers").
        shape: Border(bottom: BorderSide(color: t.hairline)),
      ),
      iconTheme: IconThemeData(color: t.ink),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.hairline,
        circularTrackColor: t.hairline,
        linearMinHeight: 3,
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: t.accent,
        textColor: t.onPrimaryAction,
      ),
      // 48px tall, but intrinsic width: full-width triggers opt in via
      // MadeenPrimaryButton, so dialog actions and button rows lay out
      // normally.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.primaryAction,
          foregroundColor: t.onPrimaryAction,
          disabledBackgroundColor: t.hairline,
          disabledForegroundColor: t.inkTertiary,
          minimumSize: const Size(64, MadeenSize.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: MadeenSpace.lg),
          shape: buttonShape,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: t.accentText,
              disabledForegroundColor: t.inkTertiary,
              minimumSize: const Size(64, MadeenSize.buttonHeight),
              padding: const EdgeInsets.symmetric(horizontal: MadeenSpace.lg),
              shape: buttonShape,
              textStyle: buttonText,
            ).copyWith(
              // A disabled secondary action drops its brass outline too.
              side: WidgetStateProperty.resolveWith(
                (states) => BorderSide(
                  color: states.contains(WidgetState.disabled)
                      ? t.hairline
                      : t.accent,
                ),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.accentText,
          textStyle: MadeenType.labelMd.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: t.ink),
      ),
      // DESIGN.md "Tactile Pill Segmented Controls": a recessed track with
      // a raised, hairline-bordered active pill.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(StadiumBorder()),
          side: WidgetStatePropertyAll(BorderSide(color: t.hairline)),
          textStyle: WidgetStatePropertyAll(MadeenType.labelMd),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? t.surfaceElevated
                : t.neutralFill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? t.ink : t.inkSecondary,
          ),
          iconColor: WidgetStatePropertyAll(t.accentText),
        ),
      ),
      // Filters, counts and tags: capsule pills (DESIGN.md "Micro-Tags"),
      // the selected one in solid ink so the choice is unmistakable.
      chipTheme: ChipThemeData(
        backgroundColor: t.neutralFill,
        selectedColor: t.primaryAction,
        disabledColor: t.neutralFill,
        checkmarkColor: t.onPrimaryAction,
        side: BorderSide(color: t.hairline),
        shape: const StadiumBorder(),
        labelStyle: MadeenType.labelMd.copyWith(color: t.ink),
        secondaryLabelStyle: MadeenType.labelMd.copyWith(
          color: t.onPrimaryAction,
        ),
        padding: const EdgeInsets.symmetric(horizontal: MadeenSpace.xs),
        showCheckmark: true,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MadeenRadius.card),
          side: BorderSide(color: t.hairline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: t.inkSecondary,
        textColor: t.ink,
        titleTextStyle: MadeenType.bodyMd.copyWith(
          color: t.ink,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: MadeenType.bodySm.copyWith(color: t.inkSecondary),
        leadingAndTrailingTextStyle: MadeenType.labelMd.copyWith(
          color: t.inkSecondary,
        ),
      ),
      // DESIGN.md "Inputs": a 1px bounding box, crisp corners, and a 1.5px
      // brass focus ring — no glow.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        labelStyle: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
        floatingLabelStyle: MadeenType.labelMd.copyWith(color: t.accentText),
        hintStyle: MadeenType.bodyMd.copyWith(color: t.inkTertiary),
        helperStyle: MadeenType.bodySm.copyWith(color: t.inkSecondary),
        errorStyle: MadeenType.bodySm.copyWith(color: t.error),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MadeenSpace.md,
          vertical: MadeenSpace.md,
        ),
        border: _box(t.hairline),
        enabledBorder: _box(t.hairline),
        disabledBorder: _box(t.hairline),
        focusedBorder: _box(t.accent, width: 1.5),
        errorBorder: _box(t.error),
        focusedErrorBorder: _box(t.error, width: 1.5),
        prefixIconColor: t.inkSecondary,
        suffixIconColor: t.inkSecondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.accent,
        selectionColor: t.accent.withValues(alpha: 0.3),
        selectionHandleColor: t.accent,
      ),
      switchTheme: SwitchThemeData(
        // A light thumb on the brass track in both modes (the dark-mode
        // onPrimaryAction is near-black, which reads as a hole).
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? (brightness == Brightness.dark ? t.ink : t.surface)
              : t.inkTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.accent : t.neutralFill,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.accent : t.hairline,
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? t.accent : t.inkTertiary,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? t.accent
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(t.onPrimaryAction),
        side: BorderSide(color: t.inkTertiary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MadeenRadius.base / 2),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: t.primaryAction,
        foregroundColor: t.onPrimaryAction,
        elevation: 1,
        highlightElevation: 1,
        extendedTextStyle: buttonText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MadeenRadius.card),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MadeenRadius.card),
          side: BorderSide(color: t.hairline),
        ),
        titleTextStyle: MadeenType.headlineMd.copyWith(color: t.ink),
        contentTextStyle: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: t.surface,
        showDragHandle: true,
        dragHandleColor: t.hairline,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(MadeenRadius.card),
          ),
          side: BorderSide(color: t.hairline),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: t.ink,
        contentTextStyle: MadeenType.bodyMd.copyWith(color: t.canvas),
        actionTextColor: t.accent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MadeenRadius.base),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        textStyle: MadeenType.bodyMd.copyWith(color: t.ink),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MadeenRadius.base),
          side: BorderSide(color: t.hairline),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(t.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MadeenRadius.base),
              side: BorderSide(color: t.hairline),
            ),
          ),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: MadeenType.labelMd.copyWith(color: t.canvas),
        decoration: BoxDecoration(
          color: t.ink,
          borderRadius: BorderRadius.circular(MadeenRadius.base),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: t.surface,
        hourMinuteColor: t.neutralFill,
        hourMinuteTextColor: t.ink,
        dialBackgroundColor: t.neutralFill,
        dialHandColor: t.accent,
        dialTextColor: t.ink,
        dayPeriodColor: t.accent.withValues(alpha: 0.2),
        dayPeriodTextColor: t.ink,
        entryModeIconColor: t.inkSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MadeenRadius.card),
        ),
      ),
      extensions: [t],
    );
  }
}
