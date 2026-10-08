import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/data/repositories/study_session_repository_impl.dart';
import 'package:mobile/features/study_session/domain/entities/answer_choice.dart';
import 'package:mobile/features/study_session/domain/entities/question.dart';
import 'package:mobile/features/study_session/domain/entities/question_feedback.dart';
import 'package:mobile/features/study_session/domain/entities/question_review_item.dart';
import 'package:mobile/features/study_session/domain/entities/question_type.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/session_result.dart';
import 'package:mobile/features/study_session/domain/entities/study_session_bundle.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mobile/features/study_session/presentation/providers/study_session_notifier.dart';
import 'package:mobile/features/study_session/presentation/providers/study_session_state.dart';
import 'package:mocktail/mocktail.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

Question _question(String id) => Question(
  id: id,
  text: 'Question $id',
  type: QuestionType.multipleChoiceSingle,
  choices: [
    AnswerChoice(id: '$id-a', text: 'A', order: 0),
    AnswerChoice(id: '$id-b', text: 'B', order: 1),
  ],
);

final _twoQuestionBundle = StudySessionBundle(
  sessionId: 'sess-1',
  questions: [_question('q1'), _question('q2')],
);

const _config = SessionConfig(
  topicId: 'topic-1',
  topicName: 'Flexible Budget',
  questionCount: 2,
  order: QuestionOrder.original,
  feedbackMode: FeedbackMode.immediate,
);

void main() {
  late MockStudySessionRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockStudySessionRepository();
    container = ProviderContainer(
      overrides: [studySessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    registerFallbackValue(<String, String?>{});
    registerFallbackValue(_config);
    registerFallbackValue(Duration.zero);
  });

  StudySessionNotifier notifier() =>
      container.read(studySessionNotifierProvider.notifier);
  StudySessionState state() => container.read(studySessionNotifierProvider);

  group('startSession', () {
    test('initial state is Initial', () {
      expect(state(), isA<StudySessionInitial>());
    });

    test('success transitions Initial -> Loading -> Active with the first question ready', () async {
      when(() => repository.startSession(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionBundle));

      final future = notifier().startSession(_config);
      expect(state(), isA<StudySessionLoading>());
      await future;

      final active = state();
      expect(active, isA<StudySessionActive>());
      active as StudySessionActive;
      expect(active.sessionId, 'sess-1');
      expect(active.totalQuestions, 2);
      expect(active.currentIndex, 0);
      expect(active.phase, QuestionPhase.ready);
      expect(active.elapsed, Duration.zero);
      expect(active.isPaused, isFalse);
    });

    test(
      'failure transitions to Error with no active snapshot to retry from',
      () async {
        when(() => repository.startSession(_config))
            .thenAnswer((_) async => const Result.failure(NetworkFailure()));

        await notifier().startSession(_config);

        final error = state();
        expect(error, isA<StudySessionError>());
        expect((error as StudySessionError).retryFrom, isNull);
      },
    );

    test('retry after a start failure calls startSession again with the same config', () async {
      var callCount = 0;
      when(() => repository.startSession(_config)).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) return const Result.failure(NetworkFailure());
        return Result.success(_twoQuestionBundle);
      });

      await notifier().startSession(_config);
      expect(state(), isA<StudySessionError>());

      await notifier().retry();

      expect(state(), isA<StudySessionActive>());
      expect(callCount, 2);
    });

    test('an empty question list is treated as an error, not a crash-prone Active session', () async {
      when(() => repository.startSession(_config)).thenAnswer(
        (_) async => const Result.success(
          StudySessionBundle(sessionId: 'sess-empty', questions: []),
        ),
      );

      await notifier().startSession(_config);

      expect(state(), isNot(isA<StudySessionActive>()));
      expect(state(), isA<StudySessionError>());
    });
  });

  group('answer selection and navigation', () {
    Future<void> start() async {
      when(() => repository.startSession(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionBundle));
      await notifier().startSession(_config);
    }

    test(
      'selecting a choice records it and moves phase to answering',
      () async {
        await start();

        notifier().selectChoice('q1-b');

        final active = state() as StudySessionActive;
        expect(active.selectedChoiceForCurrent, 'q1-b');
        expect(active.phase, QuestionPhase.answering);
      },
    );

    test(
      'changing the selection before submission overwrites the previous choice',
      () async {
        await start();

        notifier().selectChoice('q1-a');
        notifier().selectChoice('q1-b');

        expect(
          (state() as StudySessionActive).selectedChoiceForCurrent,
          'q1-b',
        );
      },
    );

    test('next/previous move between questions and are bounded', () async {
      await start();

      notifier().previousQuestion(); // no-op: already first
      expect((state() as StudySessionActive).currentIndex, 0);

      notifier().nextQuestion();
      expect((state() as StudySessionActive).currentIndex, 1);

      notifier().nextQuestion(); // no-op: already last
      expect((state() as StudySessionActive).currentIndex, 1);

      notifier().previousQuestion();
      expect((state() as StudySessionActive).currentIndex, 0);
    });

    test(
      'navigating to a question already answered restores the answering phase',
      () async {
        await start();
        notifier().selectChoice('q1-a');
        notifier().nextQuestion();
        expect((state() as StudySessionActive).phase, QuestionPhase.ready);

        notifier().previousQuestion();
        expect((state() as StudySessionActive).phase, QuestionPhase.answering);
        expect(
          (state() as StudySessionActive).selectedChoiceForCurrent,
          'q1-a',
        );
      },
    );

    test('goToQuestion jumps directly to an arbitrary index', () async {
      await start();

      notifier().goToQuestion(1);

      expect((state() as StudySessionActive).currentIndex, 1);
    });

    test(
      'answeredCount/unansweredCount reflect selections made so far',
      () async {
        await start();
        expect((state() as StudySessionActive).answeredCount, 0);

        notifier().selectChoice('q1-a');

        final active = state() as StudySessionActive;
        expect(active.answeredCount, 1);
        expect(active.unansweredCount, 1);
      },
    );
  });

  group('immediate feedback mode', () {
    Future<void> start() async {
      when(() => repository.startSession(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionBundle));
      await notifier().startSession(_config);
    }

    test('submitting an answer with nothing selected is a no-op', () async {
      await start();

      final submitted = await notifier().submitCurrentAnswer();

      expect(submitted, isFalse);
      verifyNever(
        () => repository.submitAnswer(
          sessionId: any(named: 'sessionId'),
          questionId: any(named: 'questionId'),
          selectedChoiceId: any(named: 'selectedChoiceId'),
        ),
      );
    });

    test('success reveals correctness, correct choice, and explanation, and locks the question', () async {
      await start();
      notifier().selectChoice('q1-b');

      when(
        () => repository.submitAnswer(
          sessionId: 'sess-1',
          questionId: 'q1',
          selectedChoiceId: 'q1-b',
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          QuestionFeedback(
            questionId: 'q1',
            isCorrect: false,
            correctChoiceId: 'q1-a',
            explanation: 'A is correct because...',
          ),
        ),
      );

      final submitted = await notifier().submitCurrentAnswer();

      expect(submitted, isTrue);
      final active = state() as StudySessionActive;
      expect(active.phase, QuestionPhase.feedback);
      expect(active.answeredQuestionIds, contains('q1'));
      expect(active.feedbackForCurrent?.correctChoiceId, 'q1-a');
    });

    test('selecting a different choice after feedback is shown is ignored (locked)', () async {
      await start();
      notifier().selectChoice('q1-b');
      when(
        () => repository.submitAnswer(
          sessionId: 'sess-1',
          questionId: 'q1',
          selectedChoiceId: 'q1-b',
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          QuestionFeedback(
            questionId: 'q1',
            isCorrect: false,
            correctChoiceId: 'q1-a',
          ),
        ),
      );
      await notifier().submitCurrentAnswer();

      notifier().selectChoice('q1-a');

      expect((state() as StudySessionActive).selectedChoiceForCurrent, 'q1-b');
    });

    test('failure leaves the question editable and returns false', () async {
      await start();
      notifier().selectChoice('q1-b');
      when(
        () => repository.submitAnswer(
          sessionId: 'sess-1',
          questionId: 'q1',
          selectedChoiceId: 'q1-b',
        ),
      ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

      final submitted = await notifier().submitCurrentAnswer();

      expect(submitted, isFalse);
      final active = state() as StudySessionActive;
      expect(active.phase, QuestionPhase.answering);
      expect(active.isSubmittingAnswer, isFalse);
    });

    test('is a no-op in "feedback at end" mode', () async {
      when(() => repository.startSession(any(that: isA<SessionConfig>())))
          .thenAnswer((_) async => Result.success(_twoQuestionBundle));
      final atEndConfig = SessionConfig(
        topicId: _config.topicId,
        topicName: _config.topicName,
        questionCount: _config.questionCount,
        order: _config.order,
        feedbackMode: FeedbackMode.atEnd,
      );
      await notifier().startSession(atEndConfig);
      notifier().selectChoice('q1-a');

      final submitted = await notifier().submitCurrentAnswer();

      expect(submitted, isFalse);
      verifyNever(
        () => repository.submitAnswer(
          sessionId: any(named: 'sessionId'),
          questionId: any(named: 'questionId'),
          selectedChoiceId: any(named: 'selectedChoiceId'),
        ),
      );
    });
  });

  group('count-up timer', () {
    testWidgets('increments elapsed by one second at a time while active', (
      tester,
    ) async {
      // A trivial tree so the test binding has something to draw — pump()
      // just drives the fake clock these Timer.periodic calls run on.
      await tester.pumpWidget(const SizedBox.shrink());
      when(() => repository.startSession(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionBundle));
      await notifier().startSession(_config);

      await tester.pump(const Duration(seconds: 3));

      expect(
        (state() as StudySessionActive).elapsed,
        const Duration(seconds: 3),
      );

      // Cancel the still-running Timer.periodic before the test ends —
      // flutter_test's pending-timer invariant check runs before
      // addTearDown(container.dispose) gets a chance to.
      notifier().reset();
    });

    testWidgets('togglePause stops the timer from advancing', (tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      when(() => repository.startSession(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionBundle));
      await notifier().startSession(_config);
      await tester.pump(const Duration(seconds: 2));

      notifier().togglePause();
      expect((state() as StudySessionActive).isPaused, isTrue);

      await tester.pump(const Duration(seconds: 5));
      expect(
        (state() as StudySessionActive).elapsed,
        const Duration(seconds: 2),
      );

      notifier().togglePause();
      await tester.pump(const Duration(seconds: 1));
      expect(
        (state() as StudySessionActive).elapsed,
        const Duration(seconds: 3),
      );

      notifier().reset();
    });
  });

  group('submitSession', () {
    Future<void> start() async {
      when(() => repository.startSession(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionBundle));
      await notifier().startSession(_config);
    }

    test(
      'sends the full answers map including nulls for unanswered questions',
      () async {
        await start();
        notifier().selectChoice('q1-a'); // q2 left unanswered

        when(
          () => repository.submitSession(
            sessionId: 'sess-1',
            answers: {'q1': 'q1-a', 'q2': null},
            totalTime: any(named: 'totalTime'),
          ),
        ).thenAnswer(
          (_) async => const Result.success(
            SessionResult(
              sessionId: 'sess-1',
              totalQuestions: 2,
              answered: 1,
              unanswered: 1,
              correct: 1,
              incorrect: 0,
              scorePercent: 50,
              totalTime: Duration(seconds: 10),
              averageTimePerQuestion: Duration(seconds: 5),
            ),
          ),
        );
        when(
          () => repository.getReview('sess-1'),
        ).thenAnswer((_) async => const Result.success(<QuestionReviewItem>[]));

        await notifier().submitSession();

        expect(state(), isA<StudySessionCompleted>());
        verify(
          () => repository.submitSession(
            sessionId: 'sess-1',
            answers: {'q1': 'q1-a', 'q2': null},
            totalTime: any(named: 'totalTime'),
          ),
        ).called(1);
      },
    );

    test('success fetches the review and lands on Completed with the authoritative result', () async {
      await start();

      when(
        () => repository.submitSession(
          sessionId: any(named: 'sessionId'),
          answers: any(named: 'answers'),
          totalTime: any(named: 'totalTime'),
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          SessionResult(
            sessionId: 'sess-1',
            totalQuestions: 2,
            answered: 0,
            unanswered: 2,
            correct: 0,
            incorrect: 0,
            scorePercent: 0,
            totalTime: Duration.zero,
            averageTimePerQuestion: Duration.zero,
          ),
        ),
      );
      when(() => repository.getReview('sess-1')).thenAnswer(
        (_) async => const Result.success([
          QuestionReviewItem(
            questionId: 'q1',
            questionText: 'Question q1',
            choices: [],
            correctChoiceId: 'q1-a',
            selectedChoiceId: null,
            isCorrect: false,
          ),
        ]),
      );

      await notifier().submitSession();

      final completed = state() as StudySessionCompleted;
      expect(completed.result.totalQuestions, 2);
      expect(completed.review, hasLength(1));
    });

    test(
      'a submit failure preserves every answer already made for retry',
      () async {
        await start();
        notifier().selectChoice('q1-a');

        when(
          () => repository.submitSession(
            sessionId: any(named: 'sessionId'),
            answers: any(named: 'answers'),
            totalTime: any(named: 'totalTime'),
          ),
        ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

        await notifier().submitSession();

        final error = state() as StudySessionError;
        expect(error.failure, isA<NetworkFailure>());
        expect(error.retryFrom, isNotNull);
        expect(error.retryFrom!.selectedAnswers['q1'], 'q1-a');
      },
    );

    test('retry after a submit failure restores the preserved session instead of restarting it', () async {
      await start();
      notifier().selectChoice('q1-a');
      when(
        () => repository.submitSession(
          sessionId: any(named: 'sessionId'),
          answers: any(named: 'answers'),
          totalTime: any(named: 'totalTime'),
        ),
      ).thenAnswer((_) async => const Result.failure(NetworkFailure()));
      await notifier().submitSession();

      await notifier().retry();

      final active = state() as StudySessionActive;
      expect(active.sessionId, 'sess-1');
      expect(active.selectedAnswers['q1'], 'q1-a');
      // startSession was only ever called once — the original start — not
      // again by retry(), which should restore the preserved snapshot
      // instead of restarting the session from scratch.
      verify(() => repository.startSession(any(that: isA<SessionConfig>())))
          .called(1);
    });

    test('a review-fetch failure still shows results rather than treating the submit as failed', () async {
      await start();

      when(
        () => repository.submitSession(
          sessionId: any(named: 'sessionId'),
          answers: any(named: 'answers'),
          totalTime: any(named: 'totalTime'),
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          SessionResult(
            sessionId: 'sess-1',
            totalQuestions: 2,
            answered: 0,
            unanswered: 2,
            correct: 0,
            incorrect: 0,
            scorePercent: 0,
            totalTime: Duration.zero,
            averageTimePerQuestion: Duration.zero,
          ),
        ),
      );
      when(() => repository.getReview('sess-1'))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));

      await notifier().submitSession();

      final completed = state() as StudySessionCompleted;
      expect(completed.review, isEmpty);
    });
  });

  test('reset returns to Initial', () async {
    when(() => repository.startSession(_config))
        .thenAnswer((_) async => Result.success(_twoQuestionBundle));
    await notifier().startSession(_config);
    expect(state(), isA<StudySessionActive>());

    notifier().reset();

    expect(state(), isA<StudySessionInitial>());
  });
}
