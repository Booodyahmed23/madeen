import '../../../../core/error/app_failure.dart';
import '../../domain/entities/study_reminder.dart';

/// Study Reminders screen's own state machine — same Loading/Ready/Error
/// shape as [NotificationsListState], one layer over the reminder list.
sealed class StudyRemindersState {
  const StudyRemindersState();
}

class StudyRemindersLoading extends StudyRemindersState {
  const StudyRemindersLoading();
}

class StudyRemindersReady extends StudyRemindersState {
  const StudyRemindersReady(this.reminders);

  final List<StudyReminder> reminders;
}

class StudyRemindersError extends StudyRemindersState {
  const StudyRemindersError(this.failure);

  final AppFailure failure;
}
