import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../../core/localization/locale_provider.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/entities/notification_type.dart';
import '../../domain/entities/reminder_repeat.dart';
import '../../domain/entities/study_reminder.dart';
import '../../domain/entities/weekday.dart';
import '../../domain/services/notification_scheduler.dart';
import '../../domain/services/reminder_rules.dart';

/// The platform side of [LocalNotificationScheduler], kept behind an
/// interface so the scheduling rules are testable without the plugin.
abstract class LocalNotificationsClient {
  /// Asks for notification permission (iOS, Android 13+). `false` when
  /// denied.
  Future<bool> requestPermission();

  /// Shows a notification at [at] (device local time), every week on that
  /// weekday and time when [weekly], otherwise once.
  Future<void> schedule({
    required int id,
    required DateTime at,
    required bool weekly,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);

  Future<void> cancelAll();
}

/// Study reminders as real device notifications (contract §A9: reminders
/// fire on the device; the API only stores them). Each reminder becomes up
/// to seven weekly notifications (one per day it repeats on) or a single
/// one for `ONE_TIME`, only when [reminderShouldFire] allows it.
///
/// Platform errors (no plugin in tests, permission denied) never reach the
/// caller — a reminder that can't be scheduled must not break the
/// reminders screens.
class LocalNotificationScheduler extends NotificationScheduler {
  LocalNotificationScheduler(
    this._client, {
    required this._bodyFor,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final LocalNotificationsClient _client;
  final String Function(StudyReminder reminder) _bodyFor;
  final DateTime Function() _clock;

  final Map<String, StudyReminder> _reminders = {};
  NotificationPreferences _preferences = const NotificationPreferences();
  bool? _permitted;

  /// Notification ids are ints: eight slots per reminder (seven weekdays
  /// and one for `ONE_TIME`), from a stable hash of its id.
  static int baseId(String reminderId) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(reminderId)) {
      hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
    }
    return (hash & 0x0fffffff) * 8 % 0x7ffffff8;
  }

  @override
  Future<void> applyPreferences(NotificationPreferences preferences) async {
    _preferences = preferences;
    for (final reminder in _reminders.values.toList()) {
      await update(reminder);
    }
  }

  @override
  Future<void> schedule(StudyReminder reminder) async {
    _reminders[reminder.id] = reminder;
    if (!reminderShouldFire(reminder, _preferences)) return;
    if (!await _ensurePermission()) return;
    final base = baseId(reminder.id);
    final now = _clock();
    try {
      if (reminder.repeat == ReminderRepeat.oneTime) {
        await _client.schedule(
          id: base + 7,
          at: nextTimeOfDay(now, reminder.hour, reminder.minute),
          weekly: false,
          title: reminder.title,
          body: _bodyFor(reminder),
        );
        return;
      }
      for (final day in reminder.resolvedDays) {
        await _client.schedule(
          id: base + day.index,
          at: _nextWeekday(now, day, reminder.hour, reminder.minute),
          weekly: true,
          title: reminder.title,
          body: _bodyFor(reminder),
        );
      }
    } catch (error) {
      debugPrint('Could not schedule reminder ${reminder.id}: $error');
    }
  }

  @override
  Future<void> cancel(String reminderId) async {
    _reminders.remove(reminderId);
    await _cancelSlots(reminderId);
  }

  @override
  Future<void> update(StudyReminder reminder) async {
    await _cancelSlots(reminder.id);
    await schedule(reminder);
  }

  Future<void> _cancelSlots(String reminderId) async {
    final base = baseId(reminderId);
    try {
      for (var slot = 0; slot < 8; slot++) {
        await _client.cancel(base + slot);
      }
    } catch (error) {
      debugPrint('Could not cancel reminder $reminderId: $error');
    }
  }

  @override
  Future<void> cancelAll() async {
    _reminders.clear();
    try {
      await _client.cancelAll();
    } catch (error) {
      debugPrint('Could not cancel reminders: $error');
    }
  }

  /// Asked once, the first time a reminder actually needs to fire.
  Future<bool> _ensurePermission() async {
    final known = _permitted;
    if (known != null) return known;
    try {
      return _permitted = await _client.requestPermission();
    } catch (error) {
      debugPrint('Notification permission unavailable: $error');
      return _permitted = false;
    }
  }

  static DateTime _nextWeekday(DateTime from, Weekday day, int h, int m) {
    var at = DateTime(from.year, from.month, from.day, h, m);
    while (at.weekday != day.dateTimeWeekday || !at.isAfter(from)) {
      at = DateTime(at.year, at.month, at.day + 1, h, m);
    }
    return at;
  }
}

/// [LocalNotificationsClient] over flutter_local_notifications.
class PluginNotificationsClient implements LocalNotificationsClient {
  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'study_reminders',
      'Study reminders',
      channelDescription: 'Your scheduled study and exam reminders.',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  Future<void> _init() => _ready ??= () async {
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (_) {
      // Unknown zone name: tz.local stays UTC; times are converted from
      // the device's local DateTime below, so they still fire on time.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Asked for when the first reminder is scheduled, not at launch.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
  }();

  @override
  Future<bool> requestPermission() async {
    await _init();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(alert: true, sound: true) ?? false;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime at,
    required bool weekly,
    required String title,
    required String body,
  }) async {
    await _init();
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: _details,
      // Reminders don't need to-the-second timing, and inexact alarms need
      // no extra Android permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: title,
      body: body,
      matchDateTimeComponents: weekly
          ? DateTimeComponents.dayOfWeekAndTime
          : null,
    );
  }

  @override
  Future<void> cancel(int id) async {
    await _init();
    await _plugin.cancel(id: id);
  }

  @override
  Future<void> cancelAll() async {
    await _init();
    await _plugin.cancelAll();
  }
}

/// One scheduler for the app's lifetime — it remembers what it scheduled.
final notificationSchedulerProvider = Provider<NotificationScheduler>((ref) {
  return LocalNotificationScheduler(
    PluginNotificationsClient(),
    bodyFor: (reminder) {
      final l10n = lookupAppLocalizations(
        ref.read(localeProvider) ?? PlatformDispatcher.instance.locale,
      );
      return reminder.notificationType == NotificationType.examReminder
          ? l10n.reminderNotificationExamBody
          : l10n.reminderNotificationStudyBody;
    },
  );
});
