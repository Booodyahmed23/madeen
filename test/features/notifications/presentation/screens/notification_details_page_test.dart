import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/notification_action.dart';
import 'package:mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile/features/notifications/domain/entities/notification_type.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/notifications/presentation/screens/notification_details_page.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

final _withAction = NotificationItem(
  id: 'notif-1',
  title: 'Exam simulation completed',
  body: 'Your latest results are ready.',
  createdAt: DateTime(2026, 9, 20, 7),
  type: NotificationType.performanceUpdate,
  isRead: true,
  action: const NotificationAction(
    type: NotificationActionType.openPerformanceOverview,
  ),
);

Widget _wrap(NotificationsRepository repository, String notificationId) {
  return ProviderScope(
    overrides: [notificationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NotificationDetailsPage(notificationId: notificationId),
    ),
  );
}

void main() {
  testWidgets('shows a CTA when the action resolves to a route', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getNotifications())
        .thenAnswer((_) async => Result.success([_withAction]));

    await tester.pumpWidget(_wrap(repository, 'notif-1'));
    await tester.pumpAndSettle();

    expect(find.text('Exam simulation completed'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open'), findsOneWidget);
  });

  testWidgets('shows the not-found view for an unknown id', (tester) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getNotifications())
        .thenAnswer((_) async => Result.success([_withAction]));

    await tester.pumpWidget(_wrap(repository, 'missing-id'));
    await tester.pumpAndSettle();

    expect(find.text('Notification not found'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Open'), findsNothing);
  });

  testWidgets('shows the error view with retry on a failed fetch', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getNotifications())
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository, 'notif-1'));
    await tester.pumpAndSettle();

    expect(find.text('Network error. Please try again.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });
}
