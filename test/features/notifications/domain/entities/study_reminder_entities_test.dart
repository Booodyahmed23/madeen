import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder_draft.dart';
import 'package:mobile/features/notifications/domain/entities/weekday.dart';

StudyReminder _reminder({
  required ReminderRepeat repeat,
  Set<Weekday> customDays = const {},
}) => StudyReminder(
  id: 'r1',
  title: 'Practice',
  enabled: true,
  hour: 8,
  minute: 0,
  repeat: repeat,
  customDays: customDays,
  createdAt: DateTime(2026, 9, 1),
);

void main() {
  group('StudyReminder.resolvedDays', () {
    test('everyDay resolves to all seven days', () {
      expect(
        _reminder(repeat: ReminderRepeat.everyDay).resolvedDays,
        Weekday.values.toSet(),
      );
    });

    test('weekdays resolves to Monday-Friday', () {
      expect(
        _reminder(repeat: ReminderRepeat.weekdays).resolvedDays,
        Weekday.weekdays,
      );
    });

    test('weekends resolves to Saturday-Sunday', () {
      expect(
        _reminder(repeat: ReminderRepeat.weekends).resolvedDays,
        Weekday.weekends,
      );
    });

    test('custom resolves to exactly the selected days', () {
      final days = {Weekday.monday, Weekday.wednesday};
      expect(
        _reminder(repeat: ReminderRepeat.custom, customDays: days).resolvedDays,
        days,
      );
    });

    test('oneTime resolves to no days', () {
      expect(_reminder(repeat: ReminderRepeat.oneTime).resolvedDays, isEmpty);
    });
  });

  test('StudyReminder.copyWith changes only enabled', () {
    final reminder = _reminder(repeat: ReminderRepeat.everyDay);
    final disabled = reminder.copyWith(enabled: false);

    expect(disabled.enabled, isFalse);
    expect(disabled.title, reminder.title);
    expect(disabled.hour, reminder.hour);
    expect(disabled.repeat, reminder.repeat);
  });

  group('validateStudyReminderDraft', () {
    const validDraft = StudyReminderDraft(
      title: 'Practice',
      enabled: true,
      hour: 8,
      minute: 0,
      repeat: ReminderRepeat.everyDay,
    );

    test('a valid non-custom draft has no errors', () {
      expect(validateStudyReminderDraft(validDraft), isEmpty);
    });

    test('an empty title is required', () {
      final draft = StudyReminderDraft(
        title: '   ',
        enabled: true,
        hour: 8,
        minute: 0,
        repeat: ReminderRepeat.everyDay,
      );
      expect(
        validateStudyReminderDraft(draft),
        contains(StudyReminderValidationError.titleRequired),
      );
    });

    test('a custom repeat with no days requires at least one day', () {
      const draft = StudyReminderDraft(
        title: 'Practice',
        enabled: true,
        hour: 8,
        minute: 0,
        repeat: ReminderRepeat.custom,
      );
      expect(
        validateStudyReminderDraft(draft),
        contains(StudyReminderValidationError.daysRequired),
      );
    });

    test('a custom repeat with days selected is valid', () {
      const draft = StudyReminderDraft(
        title: 'Practice',
        enabled: true,
        hour: 8,
        minute: 0,
        repeat: ReminderRepeat.custom,
        customDays: {Weekday.monday},
      );
      expect(validateStudyReminderDraft(draft), isEmpty);
    });

    test('title error is reported before days error', () {
      const draft = StudyReminderDraft(
        title: '',
        enabled: true,
        hour: 8,
        minute: 0,
        repeat: ReminderRepeat.custom,
      );
      expect(validateStudyReminderDraft(draft), [
        StudyReminderValidationError.titleRequired,
        StudyReminderValidationError.daysRequired,
      ]);
    });
  });

  group('Weekday', () {
    test('fromDateTimeWeekday round-trips with dateTimeWeekday', () {
      for (final weekday in Weekday.values) {
        expect(Weekday.fromDateTimeWeekday(weekday.dateTimeWeekday), weekday);
      }
    });

    test('wire mapping round-trips every value', () {
      for (final weekday in Weekday.values) {
        expect(Weekday.fromWire(weekday.toWire()), weekday);
      }
    });
  });

  group('ReminderRepeat wire mapping', () {
    test('round-trips every value', () {
      for (final repeat in ReminderRepeat.values) {
        expect(ReminderRepeat.fromWire(repeat.toWire()), repeat);
      }
    });
  });
}
