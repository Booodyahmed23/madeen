import '../features/notifications/domain/entities/study_reminder.dart';
import '../features/notifications/domain/entities/weekday.dart';

/// One [StudyReminder] paired with the next real [DateTime] it will fire —
/// the Home dashboard's only use of Study Reminders data, computed
/// client-side from fields [StudyReminder] already exposes
/// (`enabled`/`hour`/`minute`/`resolvedDays`). Not a new data source, not
/// persisted, and never written back to [StudyReminder] itself.
class NextStudyReminder {
  const NextStudyReminder({required this.reminder, required this.occursAt});

  final StudyReminder reminder;
  final DateTime occursAt;
}

/// The soonest-firing enabled reminder among [reminders], relative to [now]
/// — `null` when there is nothing to show (no reminders, none enabled, or
/// every enabled one is a [StudyReminder.resolvedDays]-less case this
/// calculation can't place on a calendar, e.g. `ReminderRepeat.oneTime`,
/// which this domain model has no explicit date for).
///
/// Looks up to 8 days ahead (today plus a full week) so a reminder whose
/// only day is today, already passed, still resolves to next week rather
/// than being skipped entirely.
NextStudyReminder? nextStudyReminder(
  List<StudyReminder> reminders,
  DateTime now,
) {
  NextStudyReminder? soonest;

  for (final reminder in reminders) {
    if (!reminder.enabled) continue;
    final days = reminder.resolvedDays;
    if (days.isEmpty) continue;

    for (var offset = 0; offset <= 7; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final weekday = Weekday.fromDateTimeWeekday(day.weekday);
      if (!days.contains(weekday)) continue;

      final candidate = DateTime(
        day.year,
        day.month,
        day.day,
        reminder.hour,
        reminder.minute,
      );
      if (candidate.isBefore(now)) continue;

      if (soonest == null || candidate.isBefore(soonest.occursAt)) {
        soonest = NextStudyReminder(reminder: reminder, occursAt: candidate);
      }
      break;
    }
  }

  return soonest;
}
