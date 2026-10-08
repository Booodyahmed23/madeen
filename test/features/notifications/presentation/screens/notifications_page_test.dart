import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile/features/notifications/domain/entities/notification_type.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_page.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mobile/core/network/paginated.dart';

import '../../notification_test_helpers.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

final _studyItem = NotificationItem(
  id: 'notif-1',
  title: 'Continue your CMA preparation',
  body: 'You have not practiced Financial Reporting recently.',
  createdAt: DateTime(2026, 9, 25, 8),
  type: NotificationType.studyReminder,
  isRead: false,
);
final _systemItem = NotificationItem(
  id: 'notif-2',
  title: 'App updated',
  body: 'MADEEN has been updated.',
  createdAt: DateTime(2026, 9, 20, 8),
  type: NotificationType.system,
  isRead: true,
);

Widget _wrap(
  NotificationsRepository repository, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [notificationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const NotificationsPage(),
    ),
  );
}

void main() {
  setUpAll(() => registerFallbackValue(NotificationListFilter.all));

  testWidgets('shows a loading indicator while fetching', (tester) async {
    final repository = MockNotificationsRepository();
    final completer = Completer<Result<Paginated<NotificationItem>>>();
    when(
      () => repository.getNotifications(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) => completer.future);
    when(() => repository.getUnreadCount())
        .thenAnswer((_) async => const Result.success(0));

    await tester.pumpWidget(_wrap(repository));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
    completer.complete(Result.success(pageOf(const [])));
    await tester.pumpAndSettle();
  });

  testWidgets('shows the empty state when there are no notifications', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(
      () => repository.getNotifications(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => Result.success(pageOf(const [])));
    when(() => repository.getUnreadCount())
        .thenAnswer((_) async => const Result.success(0));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('No notifications yet.'), findsOneWidget);
  });

  testWidgets('shows a localized error and retries on tap', (tester) async {
    final repository = MockNotificationsRepository();
    var callCount = 0;
    when(
      () => repository.getNotifications(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) return const Result.failure(NetworkFailure());
      return Result.success(pageOf([_studyItem]));
    });
    when(() => repository.getUnreadCount())
        .thenAnswer((_) async => const Result.success(1));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Continue your CMA preparation'), findsOneWidget);
    expect(callCount, 2);
  });

  testWidgets('the System chip asks the server for system notifications', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(
      () => repository.getNotifications(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        filter: NotificationListFilter.all,
      ),
    ).thenAnswer(
      (_) async => Result.success(pageOf([_studyItem, _systemItem])),
    );
    when(
      () => repository.getNotifications(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        filter: NotificationListFilter.system,
      ),
    ).thenAnswer((_) async => Result.success(pageOf([_systemItem])));
    when(() => repository.getUnreadCount())
        .thenAnswer((_) async => const Result.success(1));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Continue your CMA preparation'), findsOneWidget);
    expect(find.text('App updated'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'System'));
    await tester.pumpAndSettle();

    expect(find.text('Continue your CMA preparation'), findsNothing);
    expect(find.text('App updated'), findsOneWidget);
  });

  testWidgets('mark all as read calls the repository and clears the badge', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(
      () => repository.getNotifications(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => Result.success(pageOf([_studyItem])));
    when(() => repository.getUnreadCount())
        .thenAnswer((_) async => const Result.success(1));
    when(() => repository.markAllAsRead())
        .thenAnswer((_) async => const Result.success(1));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Mark all as read'), findsOneWidget);
    await tester.tap(find.text('Mark all as read'));
    await tester.pumpAndSettle();

    verify(() => repository.markAllAsRead()).called(1);
  });

  testWidgets('dismissing a notification deletes it via the repository', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(
      () => repository.getNotifications(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => Result.success(pageOf([_studyItem])));
    when(() => repository.getUnreadCount())
        .thenAnswer((_) async => const Result.success(1));
    when(() => repository.deleteNotification('notif-1'))
        .thenAnswer((_) async => const Result.success(null));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Continue your CMA preparation'),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    verify(() => repository.deleteNotification('notif-1')).called(1);
  });

  testWidgets('renders in Arabic (RTL) without crashing', (tester) async {
    final repository = MockNotificationsRepository();
    when(
      () => repository.getNotifications(
        page: any(named: 'page'),
        limit: any(named: 'limit'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => Result.success(pageOf([_studyItem])));
    when(() => repository.getUnreadCount())
        .thenAnswer((_) async => const Result.success(1));

    await tester.pumpWidget(_wrap(repository, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('الإشعارات'), findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });
}
