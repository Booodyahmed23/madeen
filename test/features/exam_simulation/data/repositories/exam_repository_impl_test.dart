import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/exam_simulation/data/datasources/exam_data_source.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_answer_choice_model.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_attempt_model.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_question_model.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_result_model.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_review_item_model.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_config.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_question_type.dart';
import 'package:mocktail/mocktail.dart';

class MockExamDataSource extends Mock implements ExamDataSource {}

void main() {
  late MockExamDataSource dataSource;
  late ExamRepositoryImpl repository;

  const config = ExamConfig(
    programId: 'program-cma',
    programName: 'CMA',
    partId: 'cma-part-1',
    partName: 'Part 1',
    questionCount: 10,
    duration: Duration(hours: 1),
  );

  setUp(() {
    dataSource = MockExamDataSource();
    repository = ExamRepositoryImpl(dataSource);
  });

  group('startExam — success', () {
    test('maps the attempt model onto the domain entity', () async {
      when(() => dataSource.startExam(config)).thenAnswer(
        (_) async => const ExamAttemptModel(
          attemptId: 'attempt-1',
          durationSeconds: 3600,
          questions: [
            ExamQuestionModel(
              id: 'q1',
              text: 'Text',
              type: ExamQuestionType.multipleChoiceSingle,
              choices: [ExamAnswerChoiceModel(id: 'q1-a', text: 'A')],
            ),
          ],
        ),
      );

      final result = await repository.startExam(config);

      expect(result, isA<Success<dynamic>>());
      final attempt = (result as Success).value;
      expect(attempt.attemptId, 'attempt-1');
      expect(attempt.durationSeconds, 3600);
    });
  });

  group('startExam — error mapping', () {
    test('maps a network failure (no response) onto NetworkFailure', () async {
      when(() => dataSource.startExam(config))
          .thenThrow(const ApiException(statusCode: 0, message: 'offline'));

      final result = await repository.startExam(config);

      expect((result as Failure).failure, isA<NetworkFailure>());
    });

    test('maps 401 onto UnauthorizedFailure', () async {
      when(() => dataSource.startExam(config)).thenThrow(
        const ApiException(statusCode: 401, message: 'Authentication required'),
      );

      final result = await repository.startExam(config);

      expect((result as Failure).failure, isA<UnauthorizedFailure>());
    });

    test('maps 500 onto ServerFailure', () async {
      when(() => dataSource.startExam(config)).thenThrow(
        const ApiException(statusCode: 500, message: 'Internal error'),
      );

      final result = await repository.startExam(config);

      expect((result as Failure).failure, isA<ServerFailure>());
    });

    test(
      'maps an unexpected error onto UnknownFailure without leaking it',
      () async {
        when(() => dataSource.startExam(config)).thenThrow(StateError('boom'));

        final result = await repository.startExam(config);

        expect((result as Failure).failure, isA<UnknownFailure>());
      },
    );
  });

  group('getAttempt', () {
    test('maps the reloaded attempt model onto the entity', () async {
      when(() => dataSource.getAttempt('attempt-1')).thenAnswer(
        (_) async => const ExamAttemptModel(
          attemptId: 'attempt-1',
          durationSeconds: 1800,
          questions: [],
        ),
      );

      final result = await repository.getAttempt('attempt-1');

      expect((result as Success).value.durationSeconds, 1800);
    });
  });

  group('submitExam', () {
    test('forwards every argument and maps the result', () async {
      final answers = {'q1': 'q1-a', 'q2': null};
      const flags = {'q2'};
      when(
        () => dataSource.submitExam(
          attemptId: 'attempt-1',
          answers: answers,
          flaggedQuestionIds: flags,
          timeTaken: const Duration(seconds: 120),
        ),
      ).thenAnswer(
        (_) async => const ExamResultModel(
          attemptId: 'attempt-1',
          totalQuestions: 2,
          answered: 1,
          unanswered: 1,
          correct: 1,
          incorrect: 0,
          scorePercent: 50.0,
          durationTakenSeconds: 120,
          completionStatus: 'completed',
        ),
      );

      final result = await repository.submitExam(
        attemptId: 'attempt-1',
        answers: answers,
        flaggedQuestionIds: flags,
        timeTaken: const Duration(seconds: 120),
      );

      expect((result as Success).value.scorePercent, 50.0);
    });
  });

  group('getReview', () {
    test('maps every review item onto its domain entity', () async {
      when(() => dataSource.getReview('attempt-1')).thenAnswer(
        (_) async => const [
          ExamReviewItemModel(
            questionId: 'q1',
            questionText: 'Text',
            choices: [ExamAnswerChoiceModel(id: 'q1-a', text: 'A')],
            correctChoiceId: 'q1-a',
            selectedChoiceId: 'q1-a',
            isCorrect: true,
            wasFlagged: false,
          ),
        ],
      );

      final result = await repository.getReview('attempt-1');

      expect((result as Success).value, hasLength(1));
    });

    test('maps a data-source error onto UnknownFailure', () async {
      when(() => dataSource.getReview('attempt-1'))
          .thenThrow(StateError('boom'));

      final result = await repository.getReview('attempt-1');

      expect((result as Failure).failure, isA<UnknownFailure>());
    });
  });
}
