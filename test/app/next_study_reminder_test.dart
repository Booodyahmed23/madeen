import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/next_study_reminder.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/entities/weekday.dart';

StudyReminder _reminder({
  String id = 'r1',
  bool enabled = true,
  required int hour,
  required int minute,
  required ReminderRepeat repeat,
  Set<Weekday> customDays = const {},
}) => StudyReminder(
  id: id,
  title: 'Practice',
  enabled: enabled,
  hour: hour,
  minute: minute,
  repeat: repeat,
  customDays: customDays,
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  // 2026-09-28 is a Monday.
  final monday9am = DateTime(2026, 9, 28, 9);

  test('returns null for an empty list', () {
    expect(nextStudyReminder([], monday9am), isNull);
  });

  test('ignores disabled reminders', () {
    final reminder = _reminder(
      enabled: false,
      hour: 10,
      minute: 0,
      repeat: ReminderRepeat.everyDay,
    );
    expect(nextStudyReminder([reminder], monday9am), isNull);
  });

  test('ignores oneTime reminders (no day this domain model can place)', () {
    final reminder = _reminder(
      hour: 10,
      minute: 0,
      repeat: ReminderRepeat.oneTime,
    );
    expect(nextStudyReminder([reminder], monday9am), isNull);
  });

  test('an everyDay reminder later today resolves to today', () {
    final reminder = _reminder(
      hour: 10,
      minute: 0,
      repeat: ReminderRepeat.everyDay,
    );
    final result = nextStudyReminder([reminder], monday9am);
    expect(result, isNotNull);
    expect(result!.occursAt, DateTime(2026, 9, 28, 10, 0));
  });

  test('an everyDay reminder earlier today rolls to tomorrow', () {
    final reminder = _reminder(
      hour: 8,
      minute: 0,
      repeat: ReminderRepeat.everyDay,
    );
    final result = nextStudyReminder([reminder], monday9am);
    expect(result!.occursAt, DateTime(2026, 9, 29, 8, 0));
  });

  test('a weekly (custom, single-day) reminder whose day already passed '
      'this week rolls to next week', () {
    final reminder = _reminder(
      hour: 8,
      minute: 0,
      repeat: ReminderRepeat.custom,
      customDays: const {Weekday.monday},
    );
    final result = nextStudyReminder([reminder], monday9am);
    expect(result!.occursAt, DateTime(2026, 10, 5, 8, 0));
  });

  test('weekdays-only resolves to the next weekday, skipping the weekend', () {
    // Friday 2026-10-02, after 8am — next weekday occurrence is Monday.
    final friday9am = DateTime(2026, 10, 2, 9);
    final reminder = _reminder(
      hour: 8,
      minute: 0,
      repeat: ReminderRepeat.weekdays,
    );
    final result = nextStudyReminder([reminder], friday9am);
    expect(result!.occursAt, DateTime(2026, 10, 5, 8, 0));
  });

  test('picks the soonest occurrence across multiple enabled reminders', () {
    final later = _reminder(
      id: 'later',
      hour: 20,
      minute: 0,
      repeat: ReminderRepeat.everyDay,
    );
    final sooner = _reminder(
      id: 'sooner',
      hour: 10,
      minute: 0,
      repeat: ReminderRepeat.everyDay,
    );
    final result = nextStudyReminder([later, sooner], monday9am);
    expect(result!.reminder.id, 'sooner');
  });
}
