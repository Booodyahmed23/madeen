import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/notifications/presentation/screens/study_reminders_page.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

final _reminder = StudyReminder(
  id: 'reminder-1',
  title: 'Daily CMA Practice',
  enabled: true,
  hour: 7,
  minute: 30,
  repeat: ReminderRepeat.everyDay,
  createdAt: DateTime(2026, 9, 1, 7, 30),
);

Widget _wrap(NotificationsRepository repository) {
  return ProviderScope(
    overrides: [notificationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const StudyRemindersPage(),
    ),
  );
}

void main() {
  testWidgets('shows the empty state when there are no reminders', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => const Result.success([]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('No study reminders yet.'), findsOneWidget);
  });

  testWidgets('lists a seeded reminder with its time and repeat pattern', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => Result.success([_reminder]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('Daily CMA Practice'), findsOneWidget);
    expect(find.textContaining('Every day'), findsOneWidget);
  });

  testWidgets('deleting a reminder confirms, then removes it', (tester) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => Result.success([_reminder]));
    when(() => repository.deleteStudyReminder('reminder-1'))
        .thenAnswer((_) async => const Result.success(null));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Delete reminder?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    verify(() => repository.deleteStudyReminder('reminder-1')).called(1);
    expect(find.text('No study reminders yet.'), findsOneWidget);
  });

  testWidgets('toggling enabled updates the switch and cancels scheduling', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => Result.success([_reminder]));
    when(() => repository.toggleStudyReminder('reminder-1', false)).thenAnswer(
      (_) async => Result.success(_reminder.copyWith(enabled: false)),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    verify(() => repository.toggleStudyReminder('reminder-1', false)).called(1);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });
}
