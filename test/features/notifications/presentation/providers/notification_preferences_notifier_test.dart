import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_preferences_providers.dart';
import 'package:mobile/features/notifications/presentation/providers/notification_preferences_state.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

const _preferences = NotificationPreferences();

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationPreferences());
  });

  late MockNotificationsRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockNotificationsRepository();
    container = ProviderContainer(
      overrides: [
        notificationsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
  });

  test('build fetches preferences, landing on Ready', () async {
    when(() => repository.getNotificationPreferences())
        .thenAnswer((_) async => const Result.success(_preferences));

    expect(
      container.read(notificationPreferencesNotifierProvider),
      isA<NotificationPreferencesLoading>(),
    );
    await _settle();

    final state = container.read(notificationPreferencesNotifierProvider);
    expect(state, isA<NotificationPreferencesReady>());
    expect(
      (state as NotificationPreferencesReady).preferences.studyReminders,
      isTrue,
    );
  });

  test('a failed fetch lands on Error', () async {
    when(() => repository.getNotificationPreferences())
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    container.read(notificationPreferencesNotifierProvider);
    await _settle();

    expect(
      container.read(notificationPreferencesNotifierProvider),
      isA<NotificationPreferencesError>(),
    );
  });

  test('setPreferences applies the update on success', () async {
    when(() => repository.getNotificationPreferences())
        .thenAnswer((_) async => const Result.success(_preferences));
    when(
      () => repository.updateNotificationPreferences(
        any(),
        previous: any(named: 'previous'),
      ),
    ).thenAnswer(
      (invocation) async => Result.success(
        invocation.positionalArguments.first as NotificationPreferences,
      ),
    );

    final notifier = container.read(
      notificationPreferencesNotifierProvider.notifier,
    );
    await _settle();
    await notifier.setPreferences(_preferences.copyWith(studyReminders: false));

    final state = container.read(
      notificationPreferencesNotifierProvider,
    ) as NotificationPreferencesReady;
    expect(state.preferences.studyReminders, isFalse);
    expect(state.saveError, isNull);
  });

  test('setPreferences rolls back and surfaces saveError on failure', () async {
    when(() => repository.getNotificationPreferences())
        .thenAnswer((_) async => const Result.success(_preferences));
    when(
      () => repository.updateNotificationPreferences(
        any(),
        previous: any(named: 'previous'),
      ),
    ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

    final notifier = container.read(
      notificationPreferencesNotifierProvider.notifier,
    );
    await _settle();
    await notifier.setPreferences(_preferences.copyWith(studyReminders: false));

    final state = container.read(
      notificationPreferencesNotifierProvider,
    ) as NotificationPreferencesReady;
    // Rolled back to the original (true), not the attempted (false) value.
    expect(state.preferences.studyReminders, isTrue);
    expect(state.saveError, isA<NetworkFailure>());
  });
}
