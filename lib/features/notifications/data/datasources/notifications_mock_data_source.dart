import '../../domain/entities/notification_action.dart';
import '../../domain/entities/notification_type.dart';
import '../../domain/entities/reminder_repeat.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/notification_item.dart';
import '../../domain/entities/notification_preferences.dart';
import '../models/notification_item_model.dart';
import '../models/notification_preferences_model.dart';
import '../models/study_reminder_model.dart';
import 'notifications_data_source.dart';

/// Local sample data, used while `NOTIFICATIONS_API_AVAILABLE` is off,
/// returning the same JSON as the API (contract §A9). This is a
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
  /// `openPerformance`) or an id already
  /// known to exist in another feature's own mock fixture (`perf-attempt-2`
  /// — see PerformanceMockDataSource — is an Exam Simulation attempt,
  /// matching notification #5's "Exam simulation completed" wording
  /// exactly). A generic reminder with no specific topic in mind carries no
  /// `targetId` at all and resolves to showing its own details instead —
  /// see NotificationActionResolver's doc comment for why guessing a
  /// plausible-looking id from a feature this one doesn't own would be
  /// worse than admitting there's nothing to deep-link to.
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: 'notif-1',
      title: 'Continue your CMA preparation',
      body: 'You have not practiced Financial Reporting recently.',
      createdAt: DateTime(2026, 9, 25, 8),
      type: NotificationType.studyReminder,
      isRead: false,
    ),
    NotificationItem(
      id: 'notif-2',
      title: 'Performance update',
      body: 'Your accuracy in Cost Management improved this week.',
      createdAt: DateTime(2026, 9, 24, 18, 30),
      type: NotificationType.performanceUpdate,
      isRead: false,
      action: NotificationAction(type: NotificationActionType.openPerformance),
    ),
    NotificationItem(
      id: 'notif-4',
      title: 'Study reminder',
      body: 'Your scheduled study session starts soon.',
      createdAt: DateTime(2026, 9, 22, 20),
      type: NotificationType.studyReminder,
      isRead: true,
    ),
    NotificationItem(
      id: 'notif-5',
      title: 'Exam simulation completed',
      body: 'Your latest CMA simulation results are ready.',
      createdAt: DateTime(2026, 9, 20, 7, 45),
      type: NotificationType.performanceUpdate,
      isRead: true,
      action: NotificationAction(
        type: NotificationActionType.openAttempt,
        targetId: 'perf-attempt-2',
        attemptType: 'EXAM',
      ),
    ),
    NotificationItem(
      id: 'notif-6',
      title: 'Achievement unlocked',
      body: "You've completed 5 Study Sessions this week — great consistency!",
      createdAt: DateTime(2026, 9, 18, 12),
      type: NotificationType.achievement,
      isRead: true,
      priority: NotificationPriority.low,
      action: NotificationAction(type: NotificationActionType.openPerformance),
    ),
    NotificationItem(
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

  NotificationPreferences _preferences = const NotificationPreferences();

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
  Future<Json> getNotifications({
    required int page,
    required int limit,
    required List<String> types,
    required bool unreadOnly,
  }) async {
    await Future<void>.delayed(_artificialDelay);
    final matching = [
      for (final n in _notifications)
        if ((types.isEmpty || types.contains(n.type.toWire())) &&
            (!unreadOnly || !n.isRead))
          n,
    ];
    return {
      'data': [
        for (final n in matching.skip((page - 1) * limit).take(limit))
          notificationToJson(n),
      ],
      'meta': {
        'page': page,
        'limit': limit,
        'total': matching.length,
        'totalPages': (matching.length / limit).ceil(),
      },
    };
  }

  @override
  Future<Json> getNotification(String notificationId) async {
    await Future<void>.delayed(_artificialDelay);
    return notificationToJson(_find(notificationId));
  }

  NotificationItem _find(String notificationId) {
    for (final n in _notifications) {
      if (n.id == notificationId) return n;
    }
    throw const ApiException(
      statusCode: 404,
      message: 'Notification not found',
      code: 'NOT_FOUND',
    );
  }

  @override
  Future<int> getUnreadCount() async {
    await Future<void>.delayed(_artificialDelay);
    return _notifications.where((n) => !n.isRead).length;
  }

  @override
  Future<Json> markAsRead(String notificationId) async {
    await Future<void>.delayed(_artificialDelay);
    final item = _find(notificationId);
    final read = item.isRead
        ? item
        : item.copyWith(isRead: true, readAt: DateTime.now().toUtc());
    _notifications[_notifications.indexOf(item)] = read;
    return notificationToJson(read);
  }

  @override
  Future<int> markAllAsRead() async {
    await Future<void>.delayed(_artificialDelay);
    var updated = 0;
    for (var i = 0; i < _notifications.length; i++) {
      if (_notifications[i].isRead) continue;
      _notifications[i] = _notifications[i].copyWith(
        isRead: true,
        readAt: DateTime.now().toUtc(),
      );
      updated++;
    }
    return updated;
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    await Future<void>.delayed(_artificialDelay);
    _notifications.remove(_find(notificationId));
  }

  @override
  Future<Json> getNotificationPreferences() async {
    await Future<void>.delayed(_artificialDelay);
    return notificationPreferencesToJson(_preferences);
  }

  @override
  Future<Json> updateNotificationPreferences(Map<String, bool> changes) async {
    await Future<void>.delayed(_artificialDelay);
    _preferences = notificationPreferencesFromJson({
      ...notificationPreferencesToJson(_preferences),
      ...changes,
    });
    return notificationPreferencesToJson(_preferences);
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
    if (_reminders.length >= 20) {
      throw const ApiException(
        statusCode: 400,
        message: 'Reminder limit reached',
        code: 'REMINDER_LIMIT_REACHED',
        details: {'max': 20},
      );
    }
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
