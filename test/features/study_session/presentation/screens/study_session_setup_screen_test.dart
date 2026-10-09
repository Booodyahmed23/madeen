import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/study_session.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_fixtures.dart';
import '../../study_session_test_harness.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

void main() {
  setUpAll(() => registerFallbackValue(testSessionConfig));

  testWidgets(
    'shows the topic name read-only and the default option selections',
    (tester) async {
      useTallSurface(tester);
      final repository = MockStudySessionRepository();

      await tester.pumpWidget(
        wrapStudySessionScreen(
          repository: repository,
          topicName: 'Flexible Budget',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flexible Budget'), findsOneWidget);
      expect(find.text('10'), findsOneWidget); // default question count chip
      // No question-order option: the server always shuffles.
      expect(find.text('Random'), findsNothing);
      expect(find.text('Immediate'), findsOneWidget);
      expect(find.text('At the end'), findsOneWidget);
    },
  );

  testWidgets(
    'starting a session sends the selected configuration to the repository',
    (tester) async {
      useTallSurface(tester);
      final repository = MockStudySessionRepository();
      final completer = Completer<Result<StudySession>>();
      when(() => repository.startSession(any()))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        wrapStudySessionScreen(repository: repository, topicId: 'topic-1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('At the end'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
      await tester.pump();

      // Shows a loading indicator while the request is in flight.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final captured = verify(() => repository.startSession(captureAny()))
          .captured;
      final config = captured.single as SessionConfig;
      expect(config.topicId, 'topic-1');
      expect(config.questionCount, 20);
      expect(config.feedbackMode, FeedbackMode.atEnd);

      completer.complete(Result.success(fakeSession()));
      await tester.pumpAndSettle();

      // Navigated to the active session screen (the Setup screen is gone).
      expect(find.text('Start session'), findsNothing);
      expect(find.text('What is 2 + 2?'), findsOneWidget);
    },
  );

  testWidgets('shows a localized error message when starting a session fails', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MockStudySessionRepository();
    when(() => repository.startSession(any()))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(wrapStudySessionScreen(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows the sample-data banner when the study session API is unavailable',
    (tester) async {
      useTallSurface(tester);
      final repository = MockStudySessionRepository();

      await tester.pumpWidget(wrapStudySessionScreen(repository: repository));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Showing sample questions — the Question Bank service isn't connected yet.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('without an active plan, Start is replaced by a way to Plans', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MockStudySessionRepository();

    await tester.pumpWidget(
      wrapStudySessionScreen(repository: repository, hasAccess: false),
    );
    await tester.pumpAndSettle();

    expect(find.text('You need an active plan'), findsOneWidget);
    expect(find.text('See plans'), findsOneWidget);
    final start = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Start session'),
    );
    expect(start.onPressed, isNull);
  });

  testWidgets('a 403 "no access" on start shows the plans notice', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MockStudySessionRepository();
    when(() => repository.startSession(any())).thenAnswer(
      (_) async => const Result.failure(
        NoAccessFailure('An active subscription is required'),
      ),
    );

    await tester.pumpWidget(wrapStudySessionScreen(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start session'));
    await tester.pumpAndSettle();

    expect(find.text('You need an active plan'), findsOneWidget);
    expect(find.text('An active subscription is required'), findsNothing);
  });

  testWidgets('a topic with no matching questions gets a clear message', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MockStudySessionRepository();
    when(() => repository.startSession(any())).thenAnswer(
      (_) async => const Result.failure(
        ValidationFailure(
          'No published questions match the selection criteria',
        ),
      ),
    );

    await tester.pumpWidget(wrapStudySessionScreen(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start session'));
    await tester.pumpAndSettle();

    expect(
      find.text('No questions are available for this topic yet.'),
      findsOneWidget,
    );
  });

  testWidgets('a custom count and a difficulty are sent with the session', (
    tester,
  ) async {
    useTallSurface(tester);
    final repository = MockStudySessionRepository();
    when(() => repository.startSession(any()))
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(wrapStudySessionScreen(repository: repository));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ChoiceChip, 'Custom'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '101');
    await tester.tap(find.widgetWithText(FilledButton, 'Set'));
    await tester.pumpAndSettle();
    expect(find.text('From 1 to 100'), findsWidgets, reason: 'rejected');
    await tester.enterText(find.byType(TextFormField), '15');
    await tester.tap(find.widgetWithText(FilledButton, 'Set'));
    await tester.pumpAndSettle();
    expect(find.text('Custom (15)'), findsOneWidget);

    await tester.tap(find.text('Hard'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Start session'));
    await tester.pumpAndSettle();

    final config =
        verify(() => repository.startSession(captureAny())).captured.single
            as SessionConfig;
    expect(config.questionCount, 15);
    expect(config.difficulty, QuestionDifficulty.hard);
    expect(config.topicIds, ['topic-1']);
  });
}
