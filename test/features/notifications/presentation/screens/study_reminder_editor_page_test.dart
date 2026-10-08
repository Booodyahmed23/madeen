import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder_draft.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/notifications/presentation/screens/study_reminder_editor_page.dart';
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

Widget _wrap(NotificationsRepository repository, {String? reminderId}) {
  return ProviderScope(
    overrides: [notificationsRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: StudyReminderEditorPage(reminderId: reminderId),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const StudyReminderDraft(
        title: '',
        enabled: true,
        hour: 0,
        minute: 0,
        repeat: ReminderRepeat.everyDay,
      ),
    );
  });

  testWidgets('shows a title-required error and does not save', (tester) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => const Result.success([]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter a title.'), findsOneWidget);
    verifyNever(() => repository.createStudyReminder(any()));
  });

  testWidgets('selecting Custom without a day shows a days-required error', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => const Result.success([]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Practice');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Custom days'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.text('Select at least one day.'), findsOneWidget);
    verifyNever(() => repository.createStudyReminder(any()));
  });

  testWidgets('a valid new reminder is created and the screen pops', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => const Result.success([]));
    when(() => repository.createStudyReminder(any()))
        .thenAnswer((_) async => Result.success(_reminder));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Navigator(
          onGenerateRoute: (settings) => MaterialPageRoute(
            builder: (context) => ProviderScope(
              overrides: [
                notificationsRepositoryProvider.overrideWithValue(repository),
              ],
              child: const StudyReminderEditorPage(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Daily CMA Practice');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    verify(() => repository.createStudyReminder(any())).called(1);
    expect(find.byType(StudyReminderEditorPage), findsNothing);
  });

  testWidgets('editing loads the existing reminder into the form', (
    tester,
  ) async {
    final repository = MockNotificationsRepository();
    when(() => repository.getStudyReminders())
        .thenAnswer((_) async => Result.success([_reminder]));

    await tester.pumpWidget(_wrap(repository, reminderId: 'reminder-1'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Reminder'), findsOneWidget);
    expect(find.text('Daily CMA Practice'), findsOneWidget);
  });
}
