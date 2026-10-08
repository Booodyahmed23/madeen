import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../data/services/local_notification_scheduler.dart';
import '../../domain/entities/study_reminder.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../../domain/services/notification_scheduler.dart';
import 'study_reminders_state.dart';

/// Owns the Study Reminders list's fetch and every mutation (create/update/
/// delete/toggle) — screens only read [StudyRemindersState] and call these
/// methods, never the repository or scheduler directly (same rule as
/// [NotificationsListNotifier]).
///
/// Every mutation that changes what should fire also tells
/// [NotificationScheduler] — still the mock implementation (see
/// `MockNotificationScheduler`'s own doc comment: this never touches a real
/// OS-level notification), but keeping it in sync here is what makes
/// `scheduledReminderIds` a truthful reflection of "what the reminders list
/// currently says should be scheduled", ready for a real scheduler to be
/// dropped in later without any change to this notifier.
class StudyRemindersNotifier extends Notifier<StudyRemindersState> {
  late NotificationsRepository _repository;
  late NotificationScheduler _scheduler;

  @override
  StudyRemindersState build() {
    _repository = ref.watch(notificationsRepositoryProvider);
    _scheduler = ref.watch(notificationSchedulerProvider);
    Future.microtask(load);
    return const StudyRemindersLoading();
  }

  Future<void> load() async {
    state = const StudyRemindersLoading();
    final result = await _repository.getStudyReminders();
    state = result.when(
      success: (reminders) {
        // The server's list is the truth: anything scheduled but no longer
        // on it (deleted on another device) goes.
        _scheduler.scheduleAll(reminders);
        return StudyRemindersReady(reminders);
      },
      failure: StudyRemindersError.new,
    );
  }

  Future<void> retry() => load();

  /// `null` on success — the editor screen pops only then, and shows the
  /// returned [AppFailure.message] otherwise (same "return the failure,
  /// don't stash it" shape [NotificationPreferencesNotifier.setPreferences]
  /// uses for its own save error).
  Future<AppFailure?> create(StudyReminderDraft draft) async {
    final result = await _repository.createStudyReminder(draft);
    return result.when(
      success: (reminder) {
        _scheduler.schedule(reminder);
        _prepend(reminder);
        return null;
      },
      failure: (failure) => failure,
    );
  }

  Future<AppFailure?> update(
    String reminderId,
    StudyReminderDraft draft,
  ) async {
    final result = await _repository.updateStudyReminder(reminderId, draft);
    return result.when(
      success: (reminder) {
        _scheduler.update(reminder);
        _replace(reminder);
        return null;
      },
      failure: (failure) => failure,
    );
  }

  Future<void> delete(String reminderId) async {
    final current = state;
    if (current is! StudyRemindersReady) return;

    final result = await _repository.deleteStudyReminder(reminderId);
    result.when(
      success: (_) {
        _scheduler.cancel(reminderId);
        state = StudyRemindersReady(
          current.reminders.where((r) => r.id != reminderId).toList(),
        );
      },
      failure: (_) {},
    );
  }

  Future<void> toggle(String reminderId, bool enabled) async {
    final current = state;
    if (current is! StudyRemindersReady) return;

    final result = await _repository.toggleStudyReminder(reminderId, enabled);
    result.when(
      success: (reminder) {
        _scheduler.update(reminder);
        _replace(reminder);
      },
      failure: (_) {},
    );
  }

  void _prepend(StudyReminder reminder) {
    final current = state;
    if (current is! StudyRemindersReady) return;
    state = StudyRemindersReady([reminder, ...current.reminders]);
  }

  void _replace(StudyReminder reminder) {
    final current = state;
    if (current is! StudyRemindersReady) return;
    state = StudyRemindersReady([
      for (final r in current.reminders)
        if (r.id == reminder.id) reminder else r,
    ]);
  }
}

final studyRemindersNotifierProvider =
    NotifierProvider<StudyRemindersNotifier, StudyRemindersState>(
      StudyRemindersNotifier.new,
    );

/// One reminder looked up by id — backs the editor's "edit" mode the same
/// way [notificationByIdProvider] backs Notification Details: a lookup into
/// whatever [studyRemindersNotifierProvider] already holds, never a second
/// fetch (this repository has no single-item `getStudyReminder(id)`).
final studyReminderByIdProvider = Provider.family<StudyReminder?, String>((
  ref,
  id,
) {
  final state = ref.watch(studyRemindersNotifierProvider);
  if (state is! StudyRemindersReady) return null;
  for (final reminder in state.reminders) {
    if (reminder.id == id) return reminder;
  }
  return null;
});
