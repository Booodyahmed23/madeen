import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/study_session/data/repositories/study_session_repository_impl.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/study_session.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mobile/features/study_session/presentation/providers/study_session_notifier.dart';
import 'package:mobile/features/study_session/presentation/providers/study_session_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_fixtures.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

void main() {
  late MockStudySessionRepository repository;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(testSessionConfig));

  setUp(() {
    repository = MockStudySessionRepository();
    container = ProviderContainer(
      overrides: [studySessionRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  StudySessionNotifier notifier() =>
      container.read(studySessionNotifierProvider.notifier);

  StudySessionState state() => container.read(studySessionNotifierProvider);

  StudySessionActive active() => state() as StudySessionActive;

  void stubAnswer(String questionId, Result<StudySession> response) {
    when(
      () => repository.answerQuestion(
        sessionId: 'sess-1',
        questionId: questionId,
        choiceId: any(named: 'choiceId'),
        timeSpentSeconds: any(named: 'timeSpentSeconds'),
      ),
    ).thenAnswer((_) async => response);
  }

  Future<void> start({
    FeedbackMode mode = FeedbackMode.immediate,
    StudySession? session,
  }) async {
    when(() => repository.startSession(any())).thenAnswer(
      (_) async => Result.success(session ?? fakeSession(feedbackMode: mode)),
    );
    await notifier().startSession(
      SessionConfig(
        topicId: 'topic-1',
        topicName: 'Flexible Budget',
        questionCount: 2,
        feedbackMode: mode,
      ),
    );
  }

  group('starting', () {
    test('a started session becomes active on its first question', () async {
      await start();

      expect(active().currentQuestion.text, 'What is 2 + 2?');
      expect(active().answeredCount, 0);
      expect(active().phase, QuestionPhase.ready);
    });

    test('a failed start becomes an error that retry repeats', () async {
      when(() => repository.startSession(any()))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));
      await notifier().startSession(testSessionConfig);
      expect(state(), isA<StudySessionError>());

      when(() => repository.startSession(any()))
          .thenAnswer((_) async => Result.success(fakeSession()));
      await notifier().retry();

      expect(state(), isA<StudySessionActive>());
    });
  });

  group('immediate mode', () {
    test('a pick is a draft until checked; checking reveals it', () async {
      await start();
      stubAnswer(
        'q1',
        Result.success(fakeSession(questions: [q1.answer('q1-a'), q2])),
      );

      await notifier().selectChoice('q1-a');
      expect(active().phase, QuestionPhase.answering);
      verifyNever(
        () => repository.answerQuestion(
          sessionId: any(named: 'sessionId'),
          questionId: any(named: 'questionId'),
          choiceId: any(named: 'choiceId'),
          timeSpentSeconds: any(named: 'timeSpentSeconds'),
        ),
      );

      expect(await notifier().submitCurrentAnswer(), isTrue);
      expect(active().phase, QuestionPhase.feedback);
      expect(active().feedbackForCurrent!.isCorrect, isFalse);
      expect(active().feedbackForCurrent!.correctChoiceId, 'q1-b');
      expect(active().answeredCount, 1);
    });

    test('a revealed question is locked against new picks', () async {
      await start(session: fakeSession(questions: [q1.answer('q1-a'), q2]));
      notifier().goToQuestion(0);

      expect(await notifier().selectChoice('q1-b'), isFalse);
      expect(active().selectedChoiceForCurrent, 'q1-a');
    });

    test('a failed check keeps the draft so it can be retried', () async {
      await start();
      stubAnswer('q1', const Result.failure(NetworkFailure()));

      await notifier().selectChoice('q1-a');
      expect(await notifier().submitCurrentAnswer(), isFalse);

      expect(active().selectedChoiceForCurrent, 'q1-a');
      expect(active().isSubmittingAnswer, isFalse);
    });
  });

  group('"at the end" mode', () {
    test('every pick is sent at once and stays hidden', () async {
      await start(mode: FeedbackMode.atEnd);
      stubAnswer(
        'q1',
        Result.success(
          fakeSession(
            feedbackMode: FeedbackMode.atEnd,
            questions: [q1.answer('q1-a'), q2],
          ),
        ),
      );

      expect(await notifier().selectChoice('q1-a'), isTrue);

      expect(active().answeredCount, 1);
      expect(active().feedbackForCurrent, isNull);
      expect(active().phase, QuestionPhase.answering);
    });

    test('a pick that fails to save falls back to the saved answer', () async {
      await start(mode: FeedbackMode.atEnd);
      stubAnswer('q1', const Result.failure(NetworkFailure()));

      expect(await notifier().selectChoice('q1-a'), isFalse);

      expect(active().selectedChoiceForCurrent, isNull);
    });
  });

  test('flags go to the server', () async {
    await start();
    when(
      () => repository.flagQuestion(
        sessionId: 'sess-1',
        questionId: 'q1',
        flagged: true,
      ),
    ).thenAnswer(
      (_) async => Result.success(fakeSession(questions: [q1.flag(true), q2])),
    );

    expect(await notifier().toggleFlag(), isTrue);
    expect(active().isCurrentFlagged, isTrue);
  });

  group('pause', () {
    test('pausing and resuming call the server', () async {
      await start();
      when(
        () => repository.pauseSession('sess-1'),
      ).thenAnswer((_) async => Result.success(fakeSession(status: 'PAUSED')));
      when(() => repository.resumeSession('sess-1'))
          .thenAnswer((_) async => Result.success(fakeSession()));

      await notifier().togglePause();
      expect(active().isPaused, isTrue);
      verify(() => repository.pauseSession('sess-1')).called(1);

      expect(await notifier().togglePause(), isTrue);
      expect(active().isPaused, isFalse);
    });

    test('a failed resume stays paused', () async {
      await start();
      when(
        () => repository.pauseSession('sess-1'),
      ).thenAnswer((_) async => Result.success(fakeSession(status: 'PAUSED')));
      when(() => repository.resumeSession('sess-1'))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));

      await notifier().togglePause();
      expect(await notifier().togglePause(), isFalse);
      expect(active().isPaused, isTrue);
    });
  });

  group('completing', () {
    test('lands on the result and review from the completed session', () async {
      await start(session: fakeSession(questions: [q1.answer('q1-b'), q2]));
      when(() => repository.completeSession('sess-1')).thenAnswer(
        (_) async => Result.success(
          fakeSession(status: 'COMPLETED', questions: [q1.answer('q1-b'), q2]),
        ),
      );

      await notifier().submitSession();

      final completed = state() as StudySessionCompleted;
      expect(completed.result.correct, 1);
      expect(completed.result.unanswered, 1);
      expect(completed.result.scorePercent, 50);
      expect(completed.review, hasLength(2));
    });

    test('a failure keeps the session to retry from', () async {
      await start();
      when(() => repository.completeSession('sess-1'))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));

      await notifier().submitSession();
      expect((state() as StudySessionError).retryFrom, isNotNull);

      await notifier().retry();
      expect(state(), isA<StudySessionActive>());
    });
  });

  group('reopening', () {
    test(
      'a paused session is resumed and opens on its first open question',
      () async {
        when(() => repository.getSession('sess-1')).thenAnswer(
          (_) async => Result.success(
            fakeSession(status: 'PAUSED', questions: [q1.answer('q1-a'), q2]),
          ),
        );
        when(() => repository.resumeSession('sess-1')).thenAnswer(
          (_) async =>
              Result.success(fakeSession(questions: [q1.answer('q1-a'), q2])),
        );

        await notifier().reopenSession('sess-1');

        verify(() => repository.resumeSession('sess-1')).called(1);
        expect(active().currentQuestion.id, 'q2');
        expect(active().config.topicName, 'Flexible Budget');
      },
    );

    test('a completed session opens on its result', () async {
      when(() => repository.getSession('sess-1')).thenAnswer(
        (_) async => Result.success(fakeSession(status: 'COMPLETED')),
      );

      await notifier().reopenSession('sess-1');

      expect(state(), isA<StudySessionCompleted>());
    });
  });

  test('navigation moves between questions within bounds', () async {
    await start();

    notifier().previousQuestion();
    expect(active().currentIndex, 0);
    notifier().nextQuestion();
    expect(active().currentIndex, 1);
    notifier().nextQuestion();
    expect(active().currentIndex, 1);
    notifier().goToQuestion(0);
    expect(active().currentIndex, 0);
  });
}
