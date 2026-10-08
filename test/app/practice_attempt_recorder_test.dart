import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/practice_attempt_recorder.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_answer_choice.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_attempt.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question_type.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_review_item.dart';
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';
import 'package:mobile/features/exam_simulation/presentation/providers/exam_notifier.dart';
import 'package:mobile/features/exam_simulation/presentation/providers/exam_state.dart';
import 'package:mobile/features/performance/data/datasources/performance_data_source.dart';
import 'package:mobile/features/performance/data/datasources/performance_local_data_source.dart';
import 'package:mobile/features/performance/data/datasources/performance_mock_data_source.dart';
import 'package:mobile/features/performance/data/datasources/performance_remote_data_source.dart';
import 'package:mobile/features/performance/data/local_attempts_provider.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/study_session/data/repositories/study_session_repository_impl.dart';
import 'package:mobile/features/study_session/domain/entities/answer_choice.dart';
import 'package:mobile/features/study_session/domain/entities/question.dart';
import 'package:mobile/features/study_session/domain/entities/question_type.dart';
import 'package:mobile/features/study_session/domain/entities/study_session_bundle.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mobile/features/study_session/presentation/providers/study_session_notifier.dart';
import 'package:mobile/features/study_session/presentation/providers/study_session_state.dart';
import 'package:mocktail/mocktail.dart';

import '../features/performance/local_attempt_test_data.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

class MockExamRepository extends Mock implements ExamRepository {}

const _session = AuthSession(
  user: AuthUser(
    id: 'user-a',
    email: 'a@example.com',
    firstName: 'A',
    lastName: 'User',
    role: 'USER',
  ),
  accessToken: 'token',
);

const _question = Question(
  id: 'q1',
  text: 'Q1',
  type: QuestionType.multipleChoiceSingle,
  choices: [AnswerChoice(id: 'c1', text: 'A')],
);

const _examQuestion = ExamQuestion(
  id: 'eq1',
  text: 'EQ1',
  type: ExamQuestionType.multipleChoiceSingle,
  choices: [ExamAnswerChoice(id: 'ec1', text: 'A')],
);

void main() {
  late MockStudySessionRepository study;
  late MockExamRepository exam;
  late ProviderContainer container;
  var now = DateTime(2026, 10, 4, 19);

  setUpAll(() {
    registerFallbackValue(varianceConfig);
    registerFallbackValue(cmaPart2Config);
    registerFallbackValue(Duration.zero);
    registerFallbackValue(<String, String?>{});
    registerFallbackValue(<String>{});
  });

  Future<void> setUpContainer({bool performanceApiAvailable = false}) async {
    final auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer((_) async => _session);

    study = MockStudySessionRepository();
    when(() => study.startSession(any())).thenAnswer(
      (_) async => const Result.success(
        StudySessionBundle(sessionId: 'mock-session-0', questions: [_question]),
      ),
    );
    when(
      () => study.submitSession(
        sessionId: any(named: 'sessionId'),
        answers: any(named: 'answers'),
        totalTime: any(named: 'totalTime'),
      ),
    ).thenAnswer((_) async => const Result.success(varianceResult));
    when(() => study.getReview(any()))
        .thenAnswer((_) async => const Result.success([]));

    exam = MockExamRepository();
    when(() => exam.startExam(any())).thenAnswer(
      (_) async => const Result.success(
        ExamAttempt(
          attemptId: 'mock-attempt-0',
          questions: [_examQuestion],
          durationSeconds: 1800,
        ),
      ),
    );
    when(
      () => exam.submitExam(
        attemptId: any(named: 'attemptId'),
        answers: any(named: 'answers'),
        flaggedQuestionIds: any(named: 'flaggedQuestionIds'),
        timeTaken: any(named: 'timeTaken'),
      ),
    ).thenAnswer((_) async => const Result.success(cmaPart2Result));
    when(() => exam.getReview(any()))
        .thenAnswer((_) async => const Result.success([]));

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        studySessionRepositoryProvider.overrideWithValue(study),
        examRepositoryProvider.overrideWithValue(exam),
        practiceClockProvider.overrideWithValue(() => now),
        performanceApiAvailableProvider.overrideWithValue(
          performanceApiAvailable,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(practiceAttemptRecorderProvider);
    container.read(localAttemptsProvider);
    await pumpEventQueue();
    container.read(localAttemptsProvider);
    await pumpEventQueue();
  }

  Future<void> completeStudySession() async {
    final notifier = container.read(studySessionNotifierProvider.notifier);
    await notifier.startSession(varianceConfig);
    await notifier.submitSession();
    await pumpEventQueue();
  }

  Future<void> completeExam() async {
    final notifier = container.read(examNotifierProvider.notifier);
    await notifier.startExam(cmaPart2Config);
    await notifier.submitExam();
    await pumpEventQueue();
  }

  List<String> recordedIds() =>
      container.read(localAttemptsProvider).map((r) => r.attemptId).toList();

  test('a completed Study Session is recorded once, with its topic', () async {
    await setUpContainer();

    await completeStudySession();

    expect(
      container.read(studySessionNotifierProvider),
      isA<StudySessionCompleted>(),
    );
    final record = container.read(localAttemptsProvider).single;
    expect(record.type, AttemptType.studySession);
    expect(record.topicId, 'topic-variance-analysis');
    expect(record.completedAt, now);
    expect(record.attemptId, startsWith('local-mock-session-0-'));
  });

  test('a completed Exam is recorded once, without a topic', () async {
    await setUpContainer();

    await completeExam();

    expect(container.read(examNotifierProvider), isA<ExamCompleted>());
    final record = container.read(localAttemptsProvider).single;
    expect(record.type, AttemptType.examSimulation);
    expect(record.topicId, isNull);
    expect(record.contentLabel, 'CMA Part 2');
  });

  test(
    'a completed Exam records its post-submission per-topic breakdown',
    () async {
      await setUpContainer();
      when(() => exam.getReview(any())).thenAnswer(
        (_) async => const Result.success([
          ExamReviewItem(
            questionId: 'eq1',
            questionText: 'EQ1',
            choices: [ExamAnswerChoice(id: 'ec1', text: 'A')],
            correctChoiceId: 'ec1',
            selectedChoiceId: 'ec1',
            isCorrect: true,
            wasFlagged: false,
            topicId: 'topic-master-budget',
            topicName: 'Master Budget',
          ),
        ]),
      );

      await completeExam();

      final record = container.read(localAttemptsProvider).single;
      expect(record.topics.single.topicId, 'topic-master-budget');
      expect(record.topics.single.correct, 1);
    },
  );

  test('rebuilding/resetting after completion never records twice', () async {
    await setUpContainer();
    await completeStudySession();

    container.read(studySessionNotifierProvider.notifier).reset();
    await pumpEventQueue();

    expect(recordedIds(), hasLength(1));
  });

  test('two completions — even with the same mock id after a "restart" — '
      'are two distinct records', () async {
    await setUpContainer();
    await completeStudySession();
    container.read(studySessionNotifierProvider.notifier).reset();
    now = now.add(const Duration(minutes: 5));
    await completeStudySession();

    expect(recordedIds(), hasLength(2));
    expect(recordedIds().toSet(), hasLength(2));
  });

  test('a failed submission records nothing', () async {
    await setUpContainer();
    when(
      () => study.submitSession(
        sessionId: any(named: 'sessionId'),
        answers: any(named: 'answers'),
        totalTime: any(named: 'totalTime'),
      ),
    ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await completeStudySession();

    expect(
      container.read(studySessionNotifierProvider),
      isA<StudySessionError>(),
    );
    expect(recordedIds(), isEmpty);
  });

  test('a session abandoned before submitting records nothing', () async {
    await setUpContainer();
    final notifier = container.read(studySessionNotifierProvider.notifier);
    await notifier.startSession(varianceConfig);
    notifier.reset();
    final examNotifier = container.read(examNotifierProvider.notifier);
    await examNotifier.startExam(cmaPart2Config);
    examNotifier.reset();
    await pumpEventQueue();

    expect(recordedIds(), isEmpty);
  });

  test('a completed attempt flows into the Performance data source', () async {
    await setUpContainer();
    await completeStudySession();

    final dataSource = container.read(performanceDataSourceProvider);

    expect(dataSource, isA<PerformanceMockDataSource>());
    final overview = await dataSource.getOverview(const PerformanceFilter());
    expect(overview.totalAttempts, 7);
  });

  group('Performance API enabled (real backend is the source of truth)', () {
    test('nothing is recorded or persisted', () async {
      await setUpContainer(performanceApiAvailable: true);

      await completeStudySession();
      await completeExam();

      expect(recordedIds(), isEmpty);
      expect(await PerformanceLocalDataSource().load('user-a'), isEmpty);
    });

    test('local attempts are never merged into the API data source', () async {
      // Even attempts recorded earlier (e.g. before the API was enabled)
      // must not reach the real-API path.
      await PerformanceLocalDataSource().save('user-a', [studyRecord()]);
      await setUpContainer(performanceApiAvailable: true);

      expect(
        container.read(performanceDataSourceProvider),
        isA<PerformanceRemoteDataSource>(),
      );
    });
  });
}
