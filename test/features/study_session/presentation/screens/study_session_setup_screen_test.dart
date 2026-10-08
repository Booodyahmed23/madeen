import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/domain/entities/answer_choice.dart';
import 'package:mobile/features/study_session/domain/entities/question.dart';
import 'package:mobile/features/study_session/domain/entities/question_type.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/study_session_bundle.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_test_harness.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const SessionConfig(
        topicId: 'x',
        topicName: 'x',
        questionCount: 10,
        order: QuestionOrder.original,
        feedbackMode: FeedbackMode.immediate,
      ),
    );
  });

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
      expect(find.text('Original'), findsOneWidget);
      expect(find.text('Random'), findsOneWidget);
      expect(find.text('Immediate'), findsOneWidget);
      expect(find.text('At the end'), findsOneWidget);
    },
  );

  testWidgets(
    'starting a session sends the selected configuration to the repository',
    (tester) async {
      useTallSurface(tester);
      final repository = MockStudySessionRepository();
      final completer = Completer<Result<StudySessionBundle>>();
      when(() => repository.startSession(any()))
          .thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        wrapStudySessionScreen(repository: repository, topicId: 'topic-1'),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Random'));
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
      expect(config.order, QuestionOrder.random);
      expect(config.feedbackMode, FeedbackMode.atEnd);

      completer.complete(
        const Result.success(
          StudySessionBundle(
            sessionId: 'sess-1',
            questions: [
              Question(
                id: 'q1',
                text: 'Sample question',
                type: QuestionType.multipleChoiceSingle,
                choices: [AnswerChoice(id: 'q1-a', text: 'A')],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Navigated to the active session screen (the Setup screen is gone).
      expect(find.text('Start session'), findsNothing);
      expect(find.text('Sample question'), findsOneWidget);
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

    expect(find.text('Network error. Please try again.'), findsOneWidget);
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
}
