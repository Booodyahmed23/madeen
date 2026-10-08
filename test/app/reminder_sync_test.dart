import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/reminder_sync.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/data/services/local_notification_scheduler.dart';
import 'package:mobile/features/notifications/data/services/mock_notification_scheduler.dart';
import 'package:mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

StudyReminder _reminder(
  String id, {
  ReminderRepeat repeat = ReminderRepeat.everyDay,
  bool enabled = true,
}) => StudyReminder(
  id: id,
  title: id,
  enabled: enabled,
  hour: 7,
  minute: 0,
  repeat: repeat,
  createdAt: DateTime(2026, 10, 7, 20),
  updatedAt: DateTime(2026, 10, 7, 20),
);

/// Runs one sync through a provider, so it gets a real Ref.
final _syncOnce = FutureProvider<void>((ref) => syncReminders(ref));

void main() {
  late MockNotificationsRepository repository;
  late MockNotificationScheduler scheduler;
  late ProviderContainer container;

  setUp(() {
    repository = MockNotificationsRepository();
    scheduler = MockNotificationScheduler();
    container = ProviderContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
        notificationSchedulerProvider.overrideWithValue(scheduler),
        // The morning after the one-time reminder was saved.
        reminderClockProvider.overrideWithValue(() => DateTime(2026, 10, 8, 9)),
      ],
    );
    addTearDown(container.dispose);
  });

  test('applies preferences, switches off a fired one-time reminder and '
      'schedules the rest', () async {
    when(() => repository.getNotificationPreferences()).thenAnswer(
      (_) async => const Result.success(
        NotificationPreferences(dailyStudyReminders: false),
      ),
    );
    final oneTime = _reminder('once', repeat: ReminderRepeat.oneTime);
    when(() => repository.getStudyReminders()).thenAnswer(
      (_) async => Result.success([
        _reminder('daily'),
        _reminder('weekdays', repeat: ReminderRepeat.weekdays),
        oneTime,
      ]),
    );
    when(
      () => repository.toggleStudyReminder('once', false),
    ).thenAnswer((_) async => Result.success(oneTime.copyWith(enabled: false)));

    await container.read(_syncOnce.future);

    verify(() => repository.toggleStudyReminder('once', false)).called(1);
    // Daily reminders are off by preference; the one-time one has fired.
    expect(scheduler.scheduledReminderIds, {'weekdays'});
  });

  test('a failed sync keeps what was scheduled and throws nothing', () async {
    await scheduler.schedule(_reminder('kept'));
    when(() => repository.getNotificationPreferences())
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await container.read(_syncOnce.future);

    expect(scheduler.scheduledReminderIds, {'kept'});
  });
}
