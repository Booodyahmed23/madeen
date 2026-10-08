import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/notifications/data/datasources/notifications_data_source.dart';
import 'package:mobile/features/notifications/data/models/notification_item_model.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/notification_type.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsDataSource extends Mock
    implements NotificationsDataSource {}

void main() {
  late MockNotificationsDataSource dataSource;
  late NotificationsRepositoryImpl repository;

  setUp(() {
    dataSource = MockNotificationsDataSource();
    repository = NotificationsRepositoryImpl(dataSource);
  });

  test('getNotifications maps every model to its entity on success', () async {
    when(() => dataSource.getNotifications()).thenAnswer(
      (_) async => [
        NotificationItemModel(
          id: 'notif-1',
          title: 'Title',
          body: 'Body',
          createdAt: DateTime(2026, 9, 25),
          type: NotificationType.system,
          isRead: false,
        ),
      ],
    );

    final result = await repository.getNotifications();

    expect(
      result.when(success: (items) => items.length, failure: (_) => -1),
      1,
    );
  });

  test('getUnreadCount surfaces an ApiException as a mapped failure', () async {
    when(
      () => dataSource.getUnreadCount(),
    ).thenThrow(const ApiException(statusCode: 500, message: 'Server error'));

    final result = await repository.getUnreadCount();

    expect(
      result.when(success: (_) => null, failure: (f) => f.runtimeType),
      ServerFailure,
    );
  });

  test('markAsRead maps an unexpected exception to UnknownFailure', () async {
    when(() => dataSource.markAsRead(any())).thenThrow(StateError('boom'));

    final result = await repository.markAsRead('notif-1');

    expect(
      result.when(success: (_) => null, failure: (f) => f.runtimeType),
      UnknownFailure,
    );
  });

  test('markAllAsRead succeeds when the data source succeeds', () async {
    when(() => dataSource.markAllAsRead()).thenAnswer((_) async {});

    final result = await repository.markAllAsRead();

    expect(result.when(success: (_) => true, failure: (_) => false), isTrue);
    verify(() => dataSource.markAllAsRead()).called(1);
  });

  test('deleteNotification delegates the id to the data source', () async {
    when(() => dataSource.deleteNotification(any())).thenAnswer((_) async {});

    await repository.deleteNotification('notif-1');

    verify(() => dataSource.deleteNotification('notif-1')).called(1);
  });
}
