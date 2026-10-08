import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_answer_choice.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_attempt.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question_type.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_result.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_review_item.dart';
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';
import 'package:mobile/features/exam_simulation/presentation/providers/exam_notifier.dart';
import 'package:mobile/features/exam_simulation/presentation/providers/exam_state.dart';
import 'package:mocktail/mocktail.dart';

class MockExamRepository extends Mock implements ExamRepository {}

ExamQuestion _question(String id) => ExamQuestion(
  id: id,
  text: 'Question $id',
  type: ExamQuestionType.multipleChoiceSingle,
  choices: [
    ExamAnswerChoice(id: '$id-a', text: 'A', order: 0),
    ExamAnswerChoice(id: '$id-b', text: 'B', order: 1),
  ],
);

final _twoQuestionAttempt = ExamAttempt(
  attemptId: 'attempt-1',
  questions: [_question('q1'), _question('q2')],
  durationSeconds: 10,
);

const _config = ExamConfig(
  programId: 'program-cma',
  programName: 'CMA',
  partId: 'cma-part-1',
  partName: 'Part 1',
  questionCount: 2,
  duration: Duration(seconds: 10),
);

void main() {
  late MockExamRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockExamRepository();
    container = ProviderContainer(
      overrides: [examRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    registerFallbackValue(<String, String?>{});
    registerFallbackValue(<String>{});
    registerFallbackValue(_config);
    registerFallbackValue(Duration.zero);
  });

  ExamNotifier notifier() => container.read(examNotifierProvider.notifier);
  ExamState state() => container.read(examNotifierProvider);

  group('startExam', () {
    test('initial state is Initial', () {
      expect(state(), isA<ExamInitial>());
    });

    test('success transitions Initial -> Loading -> Active seeded from the server-authoritative duration', () async {
      when(() => repository.startExam(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionAttempt));

      final future = notifier().startExam(_config);
      expect(state(), isA<ExamLoading>());
      await future;

      final active = state();
      expect(active, isA<ExamActive>());
      active as ExamActive;
      expect(active.attemptId, 'attempt-1');
      expect(active.totalQuestions, 2);
      expect(active.currentIndex, 0);
      expect(active.remainingSeconds, 10);
      expect(active.totalDurationSeconds, 10);
      expect(active.flaggedQuestionIds, isEmpty);
    });

    test(
      'failure transitions to Error with no active snapshot to retry from',
      () async {
        when(() => repository.startExam(_config))
            .thenAnswer((_) async => const Result.failure(NetworkFailure()));

        await notifier().startExam(_config);

        final error = state();
        expect(error, isA<ExamError>());
        expect((error as ExamError).retryFrom, isNull);
      },
    );

    test('an empty question list is treated as an error, not a crash-prone Active exam', () async {
      when(() => repository.startExam(_config)).thenAnswer(
        (_) async => const Result.success(
          ExamAttempt(
            attemptId: 'attempt-empty',
            questions: [],
            durationSeconds: 10,
          ),
        ),
      );

      await notifier().startExam(_config);

      expect(state(), isNot(isA<ExamActive>()));
      expect(state(), isA<ExamError>());
    });

    test(
      'retry after a start failure calls startExam again with the same config',
      () async {
        var callCount = 0;
        when(() => repository.startExam(_config)).thenAnswer((_) async {
          callCount++;
          if (callCount == 1) return const Result.failure(NetworkFailure());
          return Result.success(_twoQuestionAttempt);
        });

        await notifier().startExam(_config);
        expect(state(), isA<ExamError>());

        await notifier().retry();

        expect(state(), isA<ExamActive>());
        expect(callCount, 2);
      },
    );
  });

  group('answer selection, flagging, and navigation', () {
    Future<void> start() async {
      when(() => repository.startExam(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionAttempt));
      await notifier().startExam(_config);
    }

    test(
      'selecting a choice records it — no phase/lock concept exists',
      () async {
        await start();

        notifier().selectChoice('q1-b');

        expect((state() as ExamActive).selectedChoiceForCurrent, 'q1-b');
      },
    );

    test(
      'changing the selection freely overwrites the previous choice',
      () async {
        await start();

        notifier().selectChoice('q1-a');
        notifier().selectChoice('q1-b');

        expect((state() as ExamActive).selectedChoiceForCurrent, 'q1-b');
      },
    );

    test('selecting a choice never calls the repository — no per-question network call exists', () async {
      await start();

      notifier().selectChoice('q1-a');

      verifyNever(
        () => repository.submitExam(
          attemptId: any(named: 'attemptId'),
          answers: any(named: 'answers'),
          flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
          timeTaken: any(named: 'timeTaken'),
        ),
      );
    });

    test('toggleFlag flags and unflags the current question', () async {
      await start();

      notifier().toggleFlag();
      expect((state() as ExamActive).isCurrentFlagged, isTrue);
      expect((state() as ExamActive).flaggedQuestionIds, {'q1'});

      notifier().toggleFlag();
      expect((state() as ExamActive).isCurrentFlagged, isFalse);
    });

    test(
      'flagging a question does not answer it, and answering does not flag it',
      () async {
        await start();

        notifier().toggleFlag();
        final afterFlag = state() as ExamActive;
        expect(afterFlag.answeredCount, 0);

        notifier().selectChoice('q1-a');
        final afterAnswer = state() as ExamActive;
        expect(afterAnswer.flaggedQuestionIds, {'q1'});
        expect(afterAnswer.answeredCount, 1);
      },
    );

    test('next/previous move between questions, are bounded, and preserve flags independently per question', () async {
      await start();
      notifier().toggleFlag(); // flags q1

      notifier().nextQuestion();
      expect((state() as ExamActive).currentIndex, 1);
      expect(
        (state() as ExamActive).isCurrentFlagged,
        isFalse,
      ); // q2 not flagged

      notifier().nextQuestion(); // no-op: already last
      expect((state() as ExamActive).currentIndex, 1);

      notifier().previousQuestion();
      expect((state() as ExamActive).currentIndex, 0);
      expect(
        (state() as ExamActive).isCurrentFlagged,
        isTrue,
      ); // q1 still flagged

      notifier().previousQuestion(); // no-op: already first
      expect((state() as ExamActive).currentIndex, 0);
    });

    test('goToQuestion jumps directly to an arbitrary index', () async {
      await start();

      notifier().goToQuestion(1);

      expect((state() as ExamActive).currentIndex, 1);
    });

    test(
      'answeredCount/unansweredCount/flaggedCount reflect state so far',
      () async {
        await start();
        notifier().selectChoice('q1-a');
        notifier().toggleFlag();
        notifier().nextQuestion();
        notifier().toggleFlag();

        final active = state() as ExamActive;
        expect(active.answeredCount, 1);
        expect(active.unansweredCount, 1);
        expect(active.flaggedCount, 2);
      },
    );
  });

  group('countdown timer', () {
    testWidgets('decrements remainingSeconds by one second at a time', (
      tester,
    ) async {
      await tester.pumpWidget(const SizedBox.shrink());
      when(() => repository.startExam(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionAttempt));
      await notifier().startExam(_config);

      await tester.pump(const Duration(seconds: 3));

      expect((state() as ExamActive).remainingSeconds, 7);
      notifier().reset();
    });

    testWidgets(
      'cannot be paused — there is no pause method to call, and it keeps counting down regardless of navigation',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        when(() => repository.startExam(_config))
            .thenAnswer((_) async => Result.success(_twoQuestionAttempt));
        await notifier().startExam(_config);

        await tester.pump(const Duration(seconds: 2));
        notifier().nextQuestion();
        notifier().previousQuestion();
        await tester.pump(const Duration(seconds: 2));

        expect((state() as ExamActive).remainingSeconds, 6);
        notifier().reset();
      },
    );

    testWidgets(
      'reaching zero transitions Active -> Timeout and auto-submits',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        when(() => repository.startExam(_config))
            .thenAnswer((_) async => Result.success(_twoQuestionAttempt));
        await notifier().startExam(_config);

        when(
          () => repository.submitExam(
            attemptId: any(named: 'attemptId'),
            answers: any(named: 'answers'),
            flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
            timeTaken: any(named: 'timeTaken'),
          ),
        ).thenAnswer(
          (_) async => const Result.success(
            ExamResult(
              attemptId: 'attempt-1',
              totalQuestions: 2,
              answered: 0,
              unanswered: 2,
              correct: 0,
              incorrect: 0,
              scorePercent: 0,
              durationTaken: Duration(seconds: 10),
              completionStatus: 'timed_out',
            ),
          ),
        );
        when(() => repository.getReview(any()))
            .thenAnswer((_) async => const Result.success(<ExamReviewItem>[]));

        await tester.pump(const Duration(seconds: 10));
        await tester.pump(); // flush the post-timeout submit/getReview futures
        await tester.pump();

        final completed = state();
        expect(completed, isA<ExamCompleted>());
        expect(
          (completed as ExamCompleted).result.completionStatus,
          'timed_out',
        );
        verify(
          () => repository.submitExam(
            attemptId: 'attempt-1',
            answers: any(named: 'answers'),
            flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
            timeTaken: const Duration(seconds: 10),
          ),
        ).called(1);
      },
    );

    testWidgets(
      'a failed timeout submission surfaces ExamError with wasTimeout true, and retry resubmits directly',
      (tester) async {
        await tester.pumpWidget(const SizedBox.shrink());
        when(() => repository.startExam(_config))
            .thenAnswer((_) async => Result.success(_twoQuestionAttempt));
        await notifier().startExam(_config);

        var submitCallCount = 0;
        when(
          () => repository.submitExam(
            attemptId: any(named: 'attemptId'),
            answers: any(named: 'answers'),
            flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
            timeTaken: any(named: 'timeTaken'),
          ),
        ).thenAnswer((_) async {
          submitCallCount++;
          if (submitCallCount == 1) {
            return const Result.failure(NetworkFailure());
          }
          return const Result.success(
            ExamResult(
              attemptId: 'attempt-1',
              totalQuestions: 2,
              answered: 0,
              unanswered: 2,
              correct: 0,
              incorrect: 0,
              scorePercent: 0,
              durationTaken: Duration(seconds: 10),
              completionStatus: 'timed_out',
            ),
          );
        });
        when(() => repository.getReview(any()))
            .thenAnswer((_) async => const Result.success(<ExamReviewItem>[]));

        await tester.pump(const Duration(seconds: 10));
        await tester.pump();
        await tester.pump();

        final error = state();
        expect(error, isA<ExamError>());
        expect((error as ExamError).wasTimeout, isTrue);
        expect(error.retryFrom, isNotNull);

        await notifier().retry();
        await tester.pump();
        await tester.pump();

        expect(state(), isA<ExamCompleted>());
        expect(submitCallCount, 2);
      },
    );
  });

  group('submitExam (manual)', () {
    Future<void> start() async {
      when(() => repository.startExam(_config))
          .thenAnswer((_) async => Result.success(_twoQuestionAttempt));
      await notifier().startExam(_config);
    }

    test('sends the full answers map, flags, and elapsed time', () async {
      await start();
      notifier().selectChoice('q1-a'); // q2 left unanswered
      notifier().toggleFlag();

      when(
        () => repository.submitExam(
          attemptId: 'attempt-1',
          answers: {'q1': 'q1-a', 'q2': null},
          flaggedQuestionIds: {'q1'},
          timeTaken: any(named: 'timeTaken'),
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          ExamResult(
            attemptId: 'attempt-1',
            totalQuestions: 2,
            answered: 1,
            unanswered: 1,
            correct: 1,
            incorrect: 0,
            scorePercent: 50,
            durationTaken: Duration(seconds: 3),
            completionStatus: 'completed',
          ),
        ),
      );
      when(() => repository.getReview('attempt-1'))
          .thenAnswer((_) async => const Result.success(<ExamReviewItem>[]));

      await notifier().submitExam();

      expect(state(), isA<ExamCompleted>());
      verify(
        () => repository.submitExam(
          attemptId: 'attempt-1',
          answers: {'q1': 'q1-a', 'q2': null},
          flaggedQuestionIds: {'q1'},
          timeTaken: any(named: 'timeTaken'),
        ),
      ).called(1);
    });

    test('success fetches the review and lands on Completed with the authoritative result', () async {
      await start();

      when(
        () => repository.submitExam(
          attemptId: any(named: 'attemptId'),
          answers: any(named: 'answers'),
          flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
          timeTaken: any(named: 'timeTaken'),
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          ExamResult(
            attemptId: 'attempt-1',
            totalQuestions: 2,
            answered: 0,
            unanswered: 2,
            correct: 0,
            incorrect: 0,
            scorePercent: 0,
            durationTaken: Duration.zero,
            completionStatus: 'completed',
          ),
        ),
      );
      when(() => repository.getReview('attempt-1')).thenAnswer(
        (_) async => const Result.success([
          ExamReviewItem(
            questionId: 'q1',
            questionText: 'Question q1',
            choices: [],
            correctChoiceId: 'q1-a',
            selectedChoiceId: null,
            isCorrect: false,
            wasFlagged: false,
          ),
        ]),
      );

      await notifier().submitExam();

      final completed = state() as ExamCompleted;
      expect(completed.result.totalQuestions, 2);
      expect(completed.review, hasLength(1));
    });

    test(
      'a submit failure preserves every answer and flag already made for retry',
      () async {
        await start();
        notifier().selectChoice('q1-a');
        notifier().toggleFlag();

        when(
          () => repository.submitExam(
            attemptId: any(named: 'attemptId'),
            answers: any(named: 'answers'),
            flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
            timeTaken: any(named: 'timeTaken'),
          ),
        ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

        await notifier().submitExam();

        final error = state() as ExamError;
        expect(error.failure, isA<NetworkFailure>());
        expect(error.wasTimeout, isFalse);
        expect(error.retryFrom, isNotNull);
        expect(error.retryFrom!.selectedAnswers['q1'], 'q1-a');
        expect(error.retryFrom!.flaggedQuestionIds, {'q1'});
      },
    );

    test('retry after a manual submit failure restores the preserved exam and resumes the countdown', () async {
      await start();
      notifier().selectChoice('q1-a');
      when(
        () => repository.submitExam(
          attemptId: any(named: 'attemptId'),
          answers: any(named: 'answers'),
          flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
          timeTaken: any(named: 'timeTaken'),
        ),
      ).thenAnswer((_) async => const Result.failure(NetworkFailure()));
      await notifier().submitExam();

      await notifier().retry();

      final active = state() as ExamActive;
      expect(active.attemptId, 'attempt-1');
      expect(active.selectedAnswers['q1'], 'q1-a');
      verify(() => repository.startExam(any(that: isA<ExamConfig>())))
          .called(1);
      notifier().reset();
    });

    test('a review-fetch failure still shows results rather than treating the submit as failed', () async {
      await start();

      when(
        () => repository.submitExam(
          attemptId: any(named: 'attemptId'),
          answers: any(named: 'answers'),
          flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
          timeTaken: any(named: 'timeTaken'),
        ),
      ).thenAnswer(
        (_) async => const Result.success(
          ExamResult(
            attemptId: 'attempt-1',
            totalQuestions: 2,
            answered: 0,
            unanswered: 2,
            correct: 0,
            incorrect: 0,
            scorePercent: 0,
            durationTaken: Duration.zero,
            completionStatus: 'completed',
          ),
        ),
      );
      when(() => repository.getReview('attempt-1'))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));

      await notifier().submitExam();

      final completed = state() as ExamCompleted;
      expect(completed.review, isEmpty);
    });
  });

  test('reset returns to Initial', () async {
    when(() => repository.startExam(_config))
        .thenAnswer((_) async => Result.success(_twoQuestionAttempt));
    await notifier().startExam(_config);
    expect(state(), isA<ExamActive>());

    notifier().reset();

    expect(state(), isA<ExamInitial>());
  });
}
