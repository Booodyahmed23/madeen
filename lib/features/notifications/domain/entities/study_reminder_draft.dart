import 'notification_type.dart';
import 'reminder_repeat.dart';
import 'weekday.dart';

/// The editable shape the Study Reminder Editor collects — [
/// NotificationsRepository.createStudyReminder]/[updateStudyReminder] take
/// this rather than a full [StudyReminder], since `id`/`createdAt` are
/// never user-editable (the repository/backend owns assigning them).
class StudyReminderDraft {
  const StudyReminderDraft({
    required this.title,
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.repeat,
    this.customDays = const {},
    this.notificationType = NotificationType.studyReminder,
  });

  final String title;
  final bool enabled;
  final int hour;
  final int minute;
  final ReminderRepeat repeat;
  final Set<Weekday> customDays;
  final NotificationType notificationType;
}

/// A validation problem with a [StudyReminderDraft] — the editor screen
/// maps each value onto its own localized field error; kept as a pure
/// domain-level check (see [validateStudyReminderDraft]) so it is unit
/// testable without pumping a widget.
enum StudyReminderValidationError { titleRequired, daysRequired }

/// Business rule, not UI validation: a reminder needs a non-empty title,
/// and a [ReminderRepeat.custom] reminder needs at least one day selected
/// (every other repeat preset already implies a non-empty day set — see
/// [StudyReminder.resolvedDays] — so only `custom` can actually violate
/// this). Order is stable (title before days) so the editor can show a
/// deterministic first error if it only wants one.
List<StudyReminderValidationError> validateStudyReminderDraft(
  StudyReminderDraft draft,
) {
  final errors = <StudyReminderValidationError>[];
  if (draft.title.trim().isEmpty) {
    errors.add(StudyReminderValidationError.titleRequired);
  }
  if (draft.repeat == ReminderRepeat.custom && draft.customDays.isEmpty) {
    errors.add(StudyReminderValidationError.daysRequired);
  }
  return errors;
}
