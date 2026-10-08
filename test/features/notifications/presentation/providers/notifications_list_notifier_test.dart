import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile/features/notifications/domain/entities/notification_type.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/notifications/presentation/providers/notifications_list_state.dart';
import 'package:mobile/features/notifications/presentation/providers/notifications_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

final _unread = NotificationItem(
  id: 'notif-1',
  title: 'Title 1',
  body: 'Body 1',
  createdAt: DateTime(2026, 9, 25),
  type: NotificationType.studyReminder,
  isRead: false,
);
final _read = NotificationItem(
  id: 'notif-2',
  title: 'Title 2',
  body: 'Body 2',
  createdAt: DateTime(2026, 9, 24),
  type: NotificationType.system,
  isRead: true,
);

/// [NotificationsListNotifier.build] defers its first fetch to a
/// `Future.microtask` (same reason `AttemptHistoryNotifier.build` does —
/// see that notifier's own test file) — draining the microtask queue once
/// is enough to observe the resulting state without a real delay.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
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
    when(() => repository.getUnreadCount())
        .thenAnswer((_) async => const Result.success(1));
  });

  test('build triggers a fetch, landing on NotificationsListReady', () async {
    when(() => repository.getNotifications())
        .thenAnswer((_) async => Result.success([_unread, _read]));

    expect(
      container.read(notificationsListNotifierProvider),
      isA<NotificationsListLoading>(),
    );
    await _settle();

    final state = container.read(notificationsListNotifierProvider);
    expect(state, isA<NotificationsListReady>());
    expect((state as NotificationsListReady).items, hasLength(2));
  });

  test('a failed fetch lands on NotificationsListError', () async {
    when(() => repository.getNotifications())
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    container.read(notificationsListNotifierProvider);
    await _settle();

    expect(
      container.read(notificationsListNotifierProvider),
      isA<NotificationsListError>(),
    );
  });

  test('markAsRead updates only the targeted item', () async {
    when(() => repository.getNotifications())
        .thenAnswer((_) async => Result.success([_unread, _read]));
    when(() => repository.markAsRead('notif-1'))
        .thenAnswer((_) async => const Result.success(null));

    final notifier = container.read(notificationsListNotifierProvider.notifier);
    await _settle();
    await notifier.markAsRead('notif-1');

    final state = container.read(
      notificationsListNotifierProvider,
    ) as NotificationsListReady;
    expect(state.items.firstWhere((n) => n.id == 'notif-1').isRead, isTrue);
    expect(state.items.firstWhere((n) => n.id == 'notif-2').isRead, isTrue);
  });

  test('markAllAsRead marks every item read', () async {
    when(() => repository.getNotifications())
        .thenAnswer((_) async => Result.success([_unread, _read]));
    when(() => repository.markAllAsRead())
        .thenAnswer((_) async => const Result.success(null));

    final notifier = container.read(notificationsListNotifierProvider.notifier);
    await _settle();
    await notifier.markAllAsRead();

    final state = container.read(
      notificationsListNotifierProvider,
    ) as NotificationsListReady;
    expect(state.items.every((n) => n.isRead), isTrue);
  });

  test('delete removes the item from the list', () async {
    when(() => repository.getNotifications())
        .thenAnswer((_) async => Result.success([_unread, _read]));
    when(() => repository.deleteNotification('notif-1'))
        .thenAnswer((_) async => const Result.success(null));

    final notifier = container.read(notificationsListNotifierProvider.notifier);
    await _settle();
    await notifier.delete('notif-1');

    final state = container.read(
      notificationsListNotifierProvider,
    ) as NotificationsListReady;
    expect(state.items.any((n) => n.id == 'notif-1'), isFalse);
  });

  test(
    'unreadNotificationCountProvider reflects the repository count',
    () async {
      when(() => repository.getUnreadCount())
          .thenAnswer((_) async => const Result.success(3));

      final count = await container.read(
        unreadNotificationCountProvider.future,
      );

      expect(count, 3);
    },
  );

  test('notificationListFilterProvider defaults to all and updates on set', () {
    expect(
      container.read(notificationListFilterProvider),
      NotificationListFilter.all,
    );

    container
        .read(notificationListFilterProvider.notifier)
        .setFilter(NotificationListFilter.unread);
    expect(
      container.read(notificationListFilterProvider),
      NotificationListFilter.unread,
    );
  });

  test(
    'notificationByIdProvider looks up a loaded item by id, else null',
    () async {
      when(() => repository.getNotifications())
          .thenAnswer((_) async => Result.success([_unread, _read]));

      container.read(notificationsListNotifierProvider);
      await _settle();

      expect(
        container.read(notificationByIdProvider('notif-1'))?.id,
        'notif-1',
      );
      expect(container.read(notificationByIdProvider('missing')), isNull);
    },
  );
}
