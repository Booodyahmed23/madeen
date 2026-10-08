import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/data/services/local_notification_scheduler.dart';
import 'package:mobile/features/notifications/data/services/mock_notification_scheduler.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder_draft.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/notifications/presentation/providers/study_reminders_providers.dart';
import 'package:mobile/features/notifications/presentation/providers/study_reminders_state.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

StudyReminder _reminder({String id = 'reminder-1', bool enabled = true}) =>
    StudyReminder(
      id: id,
      title: 'Practice',
      enabled: enabled,
      hour: 8,
      minute: 0,
      repeat: ReminderRepeat.everyDay,
      createdAt: DateTime(2026, 9, 1),
    );

const _draft = StudyReminderDraft(
  title: 'Practice',
  enabled: true,
  hour: 8,
  minute: 0,
  repeat: ReminderRepeat.everyDay,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() {
    registerFallbackValue(_draft);
  });

  late MockNotificationsRepository repository;
  late MockNotificationScheduler mockScheduler;
  late ProviderContainer container;

  setUp(() {
    repository = MockNotificationsRepository();
    mockScheduler = MockNotificationScheduler();
    container = ProviderContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
        notificationSchedulerProvider.overrideWithValue(mockScheduler),
      ],
    );
    addTearDown(container.dispose);
  });

  test('build fetches reminders and schedules every enabled one', () async {
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => Result.success([_reminder()]));

    container.read(studyRemindersNotifierProvider);
    await _settle();

    final state =
        container.read(studyRemindersNotifierProvider) as StudyRemindersReady;
    expect(state.reminders, hasLength(1));

    final scheduler = mockScheduler;
    expect(scheduler.scheduledReminderIds, contains('reminder-1'));
  });

  test('create prepends the new reminder and schedules it', () async {
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => const Result.success([]));
    when(() => repository.createStudyReminder(any()))
        .thenAnswer((_) async => Result.success(_reminder(id: 'reminder-new')));

    final notifier = container.read(studyRemindersNotifierProvider.notifier);
    await _settle();
    final failure = await notifier.create(_draft);

    expect(failure, isNull);
    final state =
        container.read(studyRemindersNotifierProvider) as StudyRemindersReady;
    expect(state.reminders.first.id, 'reminder-new');

    final scheduler = mockScheduler;
    expect(scheduler.scheduledReminderIds, contains('reminder-new'));
  });

  test('create returns the failure without mutating the list', () async {
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => const Result.success([]));
    when(() => repository.createStudyReminder(any()))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    final notifier = container.read(studyRemindersNotifierProvider.notifier);
    await _settle();
    final failure = await notifier.create(_draft);

    expect(failure, isA<NetworkFailure>());
    final state =
        container.read(studyRemindersNotifierProvider) as StudyRemindersReady;
    expect(state.reminders, isEmpty);
  });

  test('delete cancels scheduling and removes the reminder', () async {
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => Result.success([_reminder()]));
    when(() => repository.deleteStudyReminder('reminder-1'))
        .thenAnswer((_) async => const Result.success(null));

    final notifier = container.read(studyRemindersNotifierProvider.notifier);
    await _settle();
    await notifier.delete('reminder-1');

    final state =
        container.read(studyRemindersNotifierProvider) as StudyRemindersReady;
    expect(state.reminders, isEmpty);

    final scheduler = mockScheduler;
    expect(scheduler.scheduledReminderIds, isNot(contains('reminder-1')));
  });

  test('toggle updates the scheduler and the reminder in place', () async {
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => Result.success([_reminder(enabled: true)]));
    when(() => repository.toggleStudyReminder('reminder-1', false))
        .thenAnswer((_) async => Result.success(_reminder(enabled: false)));

    final notifier = container.read(studyRemindersNotifierProvider.notifier);
    await _settle();
    await notifier.toggle('reminder-1', false);

    final state =
        container.read(studyRemindersNotifierProvider) as StudyRemindersReady;
    expect(state.reminders.single.enabled, isFalse);

    final scheduler = mockScheduler;
    expect(scheduler.scheduledReminderIds, isNot(contains('reminder-1')));
  });

  test('studyReminderByIdProvider looks up a loaded reminder by id', () async {
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => Result.success([_reminder()]));

    container.read(studyRemindersNotifierProvider);
    await _settle();

    expect(
      container.read(studyReminderByIdProvider('reminder-1'))?.id,
      'reminder-1',
    );
    expect(container.read(studyReminderByIdProvider('missing')), isNull);
  });
}
