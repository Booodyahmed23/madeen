import '../../domain/entities/notification_action.dart';
import '../../domain/entities/notification_type.dart';
import '../../domain/entities/reminder_repeat.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../models/notification_item_model.dart';
import '../models/notification_preferences_model.dart';
import '../models/study_reminder_model.dart';
import 'notifications_data_source.dart';

/// Local sample data — used only because the real Notifications API does
/// not exist yet (see NOTIFICATIONS_API_REQUIREMENTS.md). This is a
/// UI-development aid, **not** production content, selected automatically
/// when `AppConfig.isNotificationsApiAvailable` is `false` (the default) —
/// see notifications_data_source.dart.
///
/// Unlike PerformanceMockDataSource (whose fixture is read-only and
/// `static final`), this class holds **mutable, instance-level** state:
/// mark-as-read, delete, preference toggles, and reminder CRUD all need
/// somewhere to actually write to. Because `notificationsDataSourceProvider`
/// is a plain (non-`autoDispose`) `Provider`, exactly one instance of this
/// class lives for the whole app session, so those writes are visible
/// consistently across every screen — the same "one instance for the app's
/// lifetime" trick `AttemptHistoryNotifier` relies on for its own state, one
/// layer down (a datasource, not a notifier). **This state resets on app
/// restart** — there is no local persistence layer for it, matching how
/// every other mock datasource in this app behaves (see AI_ANALYSIS_API_
/// REQUIREMENTS.md's own "Current mobile-side status" for the same caveat
/// on that feature's mock).
class NotificationsMockDataSource implements NotificationsDataSource {
  static const _artificialDelay = Duration(milliseconds: 400);

  int _nextReminderId = 4;

  /// Seven notifications, most-recent-first, fixed timestamps (not
  /// `DateTime.now()`) so mock output — and every test built against it —
  /// is deterministic. The first five match the phase brief's own worked
  /// examples verbatim (title/body/type); the last two (an achievement and
  /// a system notice) exist so every `NotificationListFilter` tab has at
  /// least one real entry to show, not just the three types the brief's
  /// examples happen to cover.
  ///
  /// Deep links only ever target a route that needs no id (`openExamSetup`,
  /// `openPerformanceOverview`, `openAiAnalysisOverview`) or an id already
  /// known to exist in another feature's own mock fixture (`perf-attempt-2`
  /// — see PerformanceMockDataSource — is an Exam Simulation attempt,
  /// matching notification #5's "Exam simulation completed" wording
  /// exactly). A generic reminder with no specific topic in mind carries no
  /// `targetId` at all and resolves to showing its own details instead —
  /// see NotificationActionResolver's doc comment for why guessing a
  /// plausible-looking id from a feature this one doesn't own would be
  /// worse than admitting there's nothing to deep-link to.
  final List<NotificationItemModel> _notifications = [
    NotificationItemModel(
      id: 'notif-1',
      title: 'Continue your CMA preparation',
      body: 'You have not practiced Financial Reporting recently.',
      createdAt: DateTime(2026, 9, 25, 8),
      type: NotificationType.studyReminder,
      isRead: false,
    ),
    NotificationItemModel(
      id: 'notif-2',
      title: 'Performance update',
      body: 'Your accuracy in Cost Management improved this week.',
      createdAt: DateTime(2026, 9, 24, 18, 30),
      type: NotificationType.performanceUpdate,
      isRead: false,
      actionType: NotificationActionType.openPerformanceOverview,
    ),
    NotificationItemModel(
      id: 'notif-3',
      title: 'AI Study Recommendation',
      body:
          'MADEEN recommends a focused practice session for Performance '
          'Management.',
      createdAt: DateTime(2026, 9, 23, 9, 15),
      type: NotificationType.aiRecommendation,
      isRead: false,
      priority: NotificationPriority.high,
      actionType: NotificationActionType.openAiAnalysisOverview,
    ),
    NotificationItemModel(
      id: 'notif-4',
      title: 'Study reminder',
      body: 'Your scheduled study session starts soon.',
      createdAt: DateTime(2026, 9, 22, 20),
      type: NotificationType.studyReminder,
      isRead: true,
    ),
    NotificationItemModel(
      id: 'notif-5',
      title: 'Exam simulation completed',
      body: 'Your latest CMA simulation results are ready.',
      createdAt: DateTime(2026, 9, 20, 7, 45),
      type: NotificationType.performanceUpdate,
      isRead: true,
      actionType: NotificationActionType.openAttemptDetails,
      actionTargetId: 'perf-attempt-2',
    ),
    NotificationItemModel(
      id: 'notif-6',
      title: 'Achievement unlocked',
      body: "You've completed 5 Study Sessions this week — great consistency!",
      createdAt: DateTime(2026, 9, 18, 12),
      type: NotificationType.achievement,
      isRead: true,
      priority: NotificationPriority.low,
      actionType: NotificationActionType.openPerformanceOverview,
    ),
    NotificationItemModel(
      id: 'notif-7',
      title: 'App updated',
      body:
          'MADEEN has been updated with performance improvements and bug '
          'fixes.',
      createdAt: DateTime(2026, 9, 16, 9),
      type: NotificationType.system,
      isRead: true,
      priority: NotificationPriority.low,
    ),
  ];

  NotificationPreferencesModel _preferences =
      const NotificationPreferencesModel(
        studyReminders: true,
        dailyStudyReminders: true,
        examReminders: true,
        simulationReminders: true,
        performanceUpdates: true,
        aiRecommendations: true,
        achievements: true,
        systemNotifications: true,
      );

  /// Three reminders spanning every non-custom repeat preset plus one
  /// disabled entry, so the Study Reminders screen has something real to
  /// toggle/edit/delete out of the box.
  final List<StudyReminderModel> _reminders = [
    StudyReminderModel(
      id: 'reminder-1',
      title: 'Daily CMA Practice',
      enabled: true,
      hour: 7,
      minute: 30,
      repeat: ReminderRepeat.everyDay,
      createdAt: DateTime(2026, 9, 1, 7, 30),
    ),
    StudyReminderModel(
      id: 'reminder-2',
      title: 'Weekend Deep Review',
      enabled: true,
      hour: 10,
      minute: 0,
      repeat: ReminderRepeat.weekends,
      createdAt: DateTime(2026, 9, 5, 10),
    ),
    StudyReminderModel(
      id: 'reminder-3',
      title: 'Pre-Exam Revision',
      enabled: false,
      hour: 19,
      minute: 0,
      repeat: ReminderRepeat.weekdays,
      notificationType: NotificationType.examReminder,
      createdAt: DateTime(2026, 9, 10, 19),
    ),
  ];

  @override
  Future<List<NotificationItemModel>> getNotifications() async {
    await Future<void>.delayed(_artificialDelay);
    return List.unmodifiable(_notifications);
  }

  @override
  Future<int> getUnreadCount() async {
    await Future<void>.delayed(_artificialDelay);
    return _notifications.where((n) => !n.isRead).length;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await Future<void>.delayed(_artificialDelay);
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) {
      throw StateError('Unknown mock notification: $notificationId');
    }
    _notifications[index] = _notifications[index].copyWith(isRead: true);
  }

  @override
  Future<void> markAllAsRead() async {
    await Future<void>.delayed(_artificialDelay);
    for (var i = 0; i < _notifications.length; i++) {
      _notifications[i] = _notifications[i].copyWith(isRead: true);
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await Future<void>.delayed(_artificialDelay);
    final existed = _notifications.any((n) => n.id == notificationId);
    if (!existed) {
      throw StateError('Unknown mock notification: $notificationId');
    }
    _notifications.removeWhere((n) => n.id == notificationId);
  }

  @override
  Future<NotificationPreferencesModel> getNotificationPreferences() async {
    await Future<void>.delayed(_artificialDelay);
    return _preferences;
  }

  @override
  Future<void> updateNotificationPreferences(
    NotificationPreferencesModel preferences,
  ) async {
    await Future<void>.delayed(_artificialDelay);
    _preferences = preferences;
  }

  @override
  Future<List<StudyReminderModel>> getStudyReminders() async {
    await Future<void>.delayed(_artificialDelay);
    return List.unmodifiable(_reminders);
  }

  @override
  Future<StudyReminderModel> createStudyReminder(
    StudyReminderDraft draft,
  ) async {
    await Future<void>.delayed(_artificialDelay);
    final reminder = StudyReminderModel(
      id: 'reminder-${_nextReminderId++}',
      title: draft.title,
      enabled: draft.enabled,
      hour: draft.hour,
      minute: draft.minute,
      repeat: draft.repeat,
      customDays: draft.customDays,
      notificationType: draft.notificationType,
      createdAt: DateTime.now(),
    );
    _reminders.add(reminder);
    return reminder;
  }

  @override
  Future<StudyReminderModel> updateStudyReminder(
    String reminderId,
    StudyReminderDraft draft,
  ) async {
    await Future<void>.delayed(_artificialDelay);
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index == -1) {
      throw StateError('Unknown mock study reminder: $reminderId');
    }
    final updated = StudyReminderModel(
      id: reminderId,
      title: draft.title,
      enabled: draft.enabled,
      hour: draft.hour,
      minute: draft.minute,
      repeat: draft.repeat,
      customDays: draft.customDays,
      notificationType: draft.notificationType,
      createdAt: _reminders[index].createdAt,
    );
    _reminders[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteStudyReminder(String reminderId) async {
    await Future<void>.delayed(_artificialDelay);
    final existed = _reminders.any((r) => r.id == reminderId);
    if (!existed) {
      throw StateError('Unknown mock study reminder: $reminderId');
    }
    _reminders.removeWhere((r) => r.id == reminderId);
  }

  @override
  Future<StudyReminderModel> toggleStudyReminder(
    String reminderId,
    bool enabled,
  ) async {
    await Future<void>.delayed(_artificialDelay);
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index == -1) {
      throw StateError('Unknown mock study reminder: $reminderId');
    }
    final updated = _reminders[index].copyWith(enabled: enabled);
    _reminders[index] = updated;
    return updated;
  }
}
