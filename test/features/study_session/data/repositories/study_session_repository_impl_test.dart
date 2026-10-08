import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/study_session/data/datasources/study_session_data_source.dart';
import 'package:mobile/features/study_session/data/models/answer_choice_model.dart';
import 'package:mobile/features/study_session/data/models/question_feedback_model.dart';
import 'package:mobile/features/study_session/data/models/question_model.dart';
import 'package:mobile/features/study_session/data/models/question_review_item_model.dart';
import 'package:mobile/features/study_session/data/models/session_result_model.dart';
import 'package:mobile/features/study_session/data/models/study_session_bundle_model.dart';
import 'package:mobile/features/study_session/data/repositories/study_session_repository_impl.dart';
import 'package:mobile/features/study_session/domain/entities/question_type.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mocktail/mocktail.dart';

class MockStudySessionDataSource extends Mock
    implements StudySessionDataSource {}

void main() {
  late MockStudySessionDataSource dataSource;
  late StudySessionRepositoryImpl repository;

  const config = SessionConfig(
    topicId: 'topic-1',
    topicName: 'Flexible Budget',
    questionCount: 10,
    order: QuestionOrder.original,
    feedbackMode: FeedbackMode.immediate,
  );

  setUp(() {
    dataSource = MockStudySessionDataSource();
    repository = StudySessionRepositoryImpl(dataSource);
  });

  group('startSession — success', () {
    test('maps the bundle model onto the domain entity', () async {
      when(() => dataSource.startSession(config)).thenAnswer(
        (_) async => const StudySessionBundleModel(
          sessionId: 'sess-1',
          questions: [
            QuestionModel(
              id: 'q1',
              text: 'Text',
              type: QuestionType.multipleChoiceSingle,
              choices: [AnswerChoiceModel(id: 'q1-a', text: 'A')],
            ),
          ],
        ),
      );

      final result = await repository.startSession(config);

      expect(result, isA<Success<dynamic>>());
      final bundle = (result as Success).value;
      expect(bundle.sessionId, 'sess-1');
      expect(bundle.questions, hasLength(1));
    });
  });

  group('startSession — error mapping', () {
    test('maps a network failure (no response) onto NetworkFailure', () async {
      when(() => dataSource.startSession(config))
          .thenThrow(const ApiException(statusCode: 0, message: 'offline'));

      final result = await repository.startSession(config);

      expect((result as Failure).failure, isA<NetworkFailure>());
    });

    test('maps 401 onto UnauthorizedFailure', () async {
      when(() => dataSource.startSession(config)).thenThrow(
        const ApiException(statusCode: 401, message: 'Authentication required'),
      );

      final result = await repository.startSession(config);

      expect((result as Failure).failure, isA<UnauthorizedFailure>());
    });

    test('maps 500 onto ServerFailure', () async {
      when(() => dataSource.startSession(config)).thenThrow(
        const ApiException(statusCode: 500, message: 'Internal error'),
      );

      final result = await repository.startSession(config);

      expect((result as Failure).failure, isA<ServerFailure>());
    });

    test(
      'maps an unexpected error onto UnknownFailure without leaking it',
      () async {
        when(() => dataSource.startSession(config))
            .thenThrow(StateError('boom'));

        final result = await repository.startSession(config);

        expect((result as Failure).failure, isA<UnknownFailure>());
      },
    );
  });

  group('submitAnswer', () {
    test('forwards arguments and maps the feedback model', () async {
      when(
        () => dataSource.submitAnswer(
          sessionId: 'sess-1',
          questionId: 'q1',
          selectedChoiceId: 'q1-a',
        ),
      ).thenAnswer(
        (_) async => const QuestionFeedbackModel(
          questionId: 'q1',
          isCorrect: true,
          correctChoiceId: 'q1-a',
          explanation: 'Correct!',
        ),
      );

      final result = await repository.submitAnswer(
        sessionId: 'sess-1',
        questionId: 'q1',
        selectedChoiceId: 'q1-a',
      );

      expect(result, isA<Success<dynamic>>());
      expect((result as Success).value.isCorrect, isTrue);
    });
  });

  group('submitSession', () {
    test(
      'forwards the answers map and total time, and maps the result',
      () async {
        final answers = {'q1': 'q1-a', 'q2': null};
        when(
          () => dataSource.submitSession(
            sessionId: 'sess-1',
            answers: answers,
            totalTime: const Duration(seconds: 120),
          ),
        ).thenAnswer(
          (_) async => const SessionResultModel(
            sessionId: 'sess-1',
            totalQuestions: 2,
            answered: 1,
            unanswered: 1,
            correct: 1,
            incorrect: 0,
            scorePercent: 50.0,
            totalTimeSeconds: 120,
            averageTimePerQuestionSeconds: 60,
          ),
        );

        final result = await repository.submitSession(
          sessionId: 'sess-1',
          answers: answers,
          totalTime: const Duration(seconds: 120),
        );

        expect((result as Success).value.scorePercent, 50.0);
      },
    );
  });

  group('getReview', () {
    test('maps every review item onto its domain entity', () async {
      when(() => dataSource.getReview('sess-1')).thenAnswer(
        (_) async => const [
          QuestionReviewItemModel(
            questionId: 'q1',
            questionText: 'Text',
            choices: [AnswerChoiceModel(id: 'q1-a', text: 'A')],
            correctChoiceId: 'q1-a',
            selectedChoiceId: 'q1-a',
            isCorrect: true,
          ),
        ],
      );

      final result = await repository.getReview('sess-1') as Success;

      expect(result.value, hasLength(1));
      expect(result.value.first.isCorrect, isTrue);
    });

    test('maps a data-source error onto UnknownFailure', () async {
      when(() => dataSource.getReview('sess-1')).thenThrow(StateError('boom'));

      final result = await repository.getReview('sess-1');

      expect((result as Failure).failure, isA<UnknownFailure>());
    });
  });
}
