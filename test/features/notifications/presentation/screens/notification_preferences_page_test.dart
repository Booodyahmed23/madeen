import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/notifications/presentation/screens/notification_preferences_page.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

Widget _wrap(NotificationsRepository repository) {
  return ProviderScope(
    overrides: [notificationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const NotificationPreferencesPage(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationPreferences());
  });

  testWidgets('renders every section and toggle when loaded', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = MockNotificationsRepository();
    when(
      () => repository.getNotificationPreferences(),
    ).thenAnswer((_) async => const Result.success(NotificationPreferences()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Study reminders'), findsOneWidget);
    expect(find.text('Exam reminders'), findsOneWidget);
    expect(find.text('Performance updates'), findsOneWidget);
    expect(find.text('AI recommendations'), findsOneWidget);
    expect(find.text('Achievements and milestones'), findsOneWidget);
    expect(find.text('Important system notifications'), findsOneWidget);
  });

  testWidgets('toggling a switch persists the update through the repository', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(
      () => repository.getNotificationPreferences(),
    ).thenAnswer((_) async => const Result.success(NotificationPreferences()));
    when(() => repository.updateNotificationPreferences(any()))
        .thenAnswer((_) async => const Result.success(null));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Study reminders'));
    await tester.pumpAndSettle();

    final captured = verify(
      () => repository.updateNotificationPreferences(captureAny()),
    ).captured;
    expect(
      (captured.single as NotificationPreferences).studyReminders,
      isFalse,
    );
  });

  testWidgets('a failed update rolls back and shows the save error', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(
      () => repository.getNotificationPreferences(),
    ).thenAnswer((_) async => const Result.success(NotificationPreferences()));
    when(() => repository.updateNotificationPreferences(any()))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Study reminders'));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Study reminders'),
          )
          .value,
      isTrue, // rolled back
    );
    expect(
      find.text('Unable to save this setting. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('shows the error view with retry on a failed fetch', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getNotificationPreferences())
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Network error. Please try again.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });
}
