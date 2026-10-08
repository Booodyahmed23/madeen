import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mobile/features/notifications/domain/entities/notification_type.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/services/reminder_rules.dart';

StudyReminder _reminder({
  ReminderRepeat repeat = ReminderRepeat.weekdays,
  NotificationType type = NotificationType.studyReminder,
  bool enabled = true,
  int hour = 7,
  DateTime? updatedAt,
}) => StudyReminder(
  id: 'r1',
  title: 'Practice',
  enabled: enabled,
  hour: hour,
  minute: 30,
  repeat: repeat,
  notificationType: type,
  createdAt: DateTime(2026, 10, 1),
  updatedAt: updatedAt,
);

void main() {
  group('reminderShouldFire', () {
    const all = NotificationPreferences();

    test('a disabled reminder never fires', () {
      expect(reminderShouldFire(_reminder(enabled: false), all), isFalse);
    });

    test('study reminders follow "Study reminders"', () {
      expect(reminderShouldFire(_reminder(), all), isTrue);
      expect(
        reminderShouldFire(_reminder(), all.copyWith(studyReminders: false)),
        isFalse,
      );
    });

    test('daily study reminders also follow "Daily study reminders"', () {
      final daily = _reminder(repeat: ReminderRepeat.everyDay);
      final off = all.copyWith(dailyStudyReminders: false);

      expect(reminderShouldFire(daily, off), isFalse);
      expect(reminderShouldFire(_reminder(), off), isTrue);
    });

    test('exam reminders follow "Exam reminders" only', () {
      final exam = _reminder(type: NotificationType.examReminder);

      expect(
        reminderShouldFire(exam, all.copyWith(studyReminders: false)),
        isTrue,
      );
      expect(
        reminderShouldFire(exam, all.copyWith(examReminders: false)),
        isFalse,
      );
    });
  });

  test('nextTimeOfDay is later today, or tomorrow once passed', () {
    final morning = DateTime(2026, 10, 8, 6);
    expect(nextTimeOfDay(morning, 7, 30), DateTime(2026, 10, 8, 7, 30));
    final evening = DateTime(2026, 10, 8, 20);
    expect(nextTimeOfDay(evening, 7, 30), DateTime(2026, 10, 9, 7, 30));
  });

  test('a one-time reminder has fired once its time passed since saving', () {
    final saved = DateTime(2026, 10, 8, 6);
    final oneTime = _reminder(
      repeat: ReminderRepeat.oneTime,
      updatedAt: saved.toUtc(),
    );

    expect(oneTimeReminderHasFired(oneTime, DateTime(2026, 10, 8, 7)), isFalse);
    expect(oneTimeReminderHasFired(oneTime, DateTime(2026, 10, 8, 8)), isTrue);
    expect(
      oneTimeReminderHasFired(_reminder(updatedAt: saved), DateTime(2027)),
      isFalse,
      reason: 'repeating reminders never "fire once"',
    );
  });
}
