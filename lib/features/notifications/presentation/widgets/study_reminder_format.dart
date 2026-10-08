import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/reminder_repeat.dart';
import '../../domain/entities/weekday.dart';

/// The localized label for a [ReminderRepeat] preset — shown on both the
/// Study Reminders list and the editor's own repeat selector.
String reminderRepeatLabel(AppLocalizations l10n, ReminderRepeat repeat) =>
    switch (repeat) {
      ReminderRepeat.oneTime => l10n.reminderRepeatOneTime,
      ReminderRepeat.everyDay => l10n.reminderRepeatEveryDay,
      ReminderRepeat.weekdays => l10n.reminderRepeatWeekdays,
      ReminderRepeat.weekends => l10n.reminderRepeatWeekends,
      ReminderRepeat.custom => l10n.reminderRepeatCustom,
    };

/// The short (3-letter) localized label for a single [Weekday] — used by
/// both the reminders list's day summary and the editor's day chips.
String weekdayShortLabel(AppLocalizations l10n, Weekday weekday) =>
    switch (weekday) {
      Weekday.monday => l10n.weekdayMonShort,
      Weekday.tuesday => l10n.weekdayTueShort,
      Weekday.wednesday => l10n.weekdayWedShort,
      Weekday.thursday => l10n.weekdayThuShort,
      Weekday.friday => l10n.weekdayFriShort,
      Weekday.saturday => l10n.weekdaySatShort,
      Weekday.sunday => l10n.weekdaySunShort,
    };

/// "Mon, Wed, Fri" — [Weekday]'s own declaration order (Monday first),
/// never the order the student happened to tap them in.
String weekdaysSummary(AppLocalizations l10n, Set<Weekday> days) {
  final ordered = Weekday.values.where(days.contains);
  return ordered.map((d) => weekdayShortLabel(l10n, d)).join(', ');
}

/// `HH:mm` in 24-hour form is what [StudyReminder]/[StudyReminderDraft]
/// store — this formats it through [MaterialLocalizations.formatTimeOfDay]
/// so display respects the current locale's clock convention (12-hour with
/// localized AM/PM in English, whatever `ar`'s own Material localization
/// prescribes in Arabic) rather than a hardcoded English "AM"/"PM" string.
String formatReminderTime(BuildContext context, int hour, int minute) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatTimeOfDay(
    TimeOfDay(hour: hour % 24, minute: minute % 60),
    alwaysUse24HourFormat: false,
  );
}
