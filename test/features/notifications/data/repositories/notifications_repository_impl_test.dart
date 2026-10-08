import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/notifications/data/datasources/notifications_data_source.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile/features/notifications/domain/entities/notification_preferences.dart';
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

  test('a filter chip becomes the API query', () async {
    when(
      () => dataSource.getNotifications(
        page: 2,
        limit: 20,
        types: const ['PERFORMANCE_UPDATE', 'ACHIEVEMENT'],
        unreadOnly: false,
      ),
    ).thenAnswer(
      (_) async => {
        'data': <Object>[],
        'meta': {'page': 2, 'limit': 20, 'total': 20, 'totalPages': 2},
      },
    );

    final result = await repository.getNotifications(
      page: 2,
      filter: NotificationListFilter.performance,
    );

    expect((result as Success).value.hasMore, isFalse);
  });

  test('unchanged preferences make no call', () async {
    const prefs = NotificationPreferences();

    final result = await repository.updateNotificationPreferences(
      prefs,
      previous: prefs,
    );

    expect(result, isA<Success<NotificationPreferences>>());
    verifyNever(() => dataSource.updateNotificationPreferences(any()));
  });

  test('a changed preference is sent alone', () async {
    when(
      () => dataSource.updateNotificationPreferences({'achievements': false}),
    ).thenAnswer((_) async => {'achievements': false});

    final result = await repository.updateNotificationPreferences(
      const NotificationPreferences(achievements: false),
      previous: const NotificationPreferences(),
    );

    expect((result as Success).value.achievements, isFalse);
  });

  test('a 404 for one notification becomes NotFoundFailure', () async {
    when(() => dataSource.getNotification('x')).thenThrow(
      const ApiException(
        statusCode: 404,
        message: 'Not found',
        code: 'NOT_FOUND',
      ),
    );

    final result = await repository.getNotification('x');

    expect((result as Failure).failure, isA<NotFoundFailure>());
  });
}
