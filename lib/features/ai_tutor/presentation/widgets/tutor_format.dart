import 'package:flutter/material.dart';

/// Locale-aware time-of-day for a message bubble's timestamp, via
/// [MaterialLocalizations] rather than a hand-rolled AM/PM string — same
/// reasoning as `study_reminder_format.dart`'s own `formatReminderTime`:
/// respects the current locale's clock convention instead of leaking
/// English "AM"/"PM" into the Arabic UI.
String formatTutorMessageTime(BuildContext context, DateTime timestamp) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatTimeOfDay(
    TimeOfDay(hour: timestamp.hour, minute: timestamp.minute),
    alwaysUse24HourFormat: false,
  );
}
