import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/performance/data/datasources/performance_data_source.dart';
import 'package:mobile/features/performance/data/models/attempt_details_model.dart';
import 'package:mobile/features/performance/data/models/attempt_history_page_model.dart';
import 'package:mobile/features/performance/data/models/attempt_summary_model.dart';
import 'package:mobile/features/performance/data/models/performance_overview_model.dart';
import 'package:mobile/features/performance/data/models/topic_performance_model.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceDataSource extends Mock implements PerformanceDataSource {}

void main() {
  late MockPerformanceDataSource dataSource;
  late PerformanceRepositoryImpl repository;

  const filter = PerformanceFilter();

  setUpAll(() {
    registerFallbackValue(filter);
  });

  setUp(() {
    dataSource = MockPerformanceDataSource();
    repository = PerformanceRepositoryImpl(dataSource);
  });

  group('getOverview', () {
    test('maps the model onto the domain entity', () async {
      when(() => dataSource.getOverview(filter)).thenAnswer(
        (_) async => const PerformanceOverviewModel(
          totalAttempts: 6,
          questionsPracticed: 205,
          totalAnswered: 197,
          totalCorrect: 151,
          overallScorePercent: 73.66,
          totalTimeSeconds: 25000,
          averageTimePerQuestionSeconds: 121,
        ),
      );

      final result = await repository.getOverview(filter: filter);

      expect((result as Success).value.totalAttempts, 6);
    });

    test('maps a network failure onto NetworkFailure', () async {
      when(() => dataSource.getOverview(filter))
          .thenThrow(const ApiException(statusCode: 0, message: 'offline'));

      final result = await repository.getOverview(filter: filter);

      expect((result as Failure).failure, isA<NetworkFailure>());
    });

    test('maps an unexpected error onto UnknownFailure', () async {
      when(() => dataSource.getOverview(filter)).thenThrow(StateError('boom'));

      final result = await repository.getOverview(filter: filter);

      expect((result as Failure).failure, isA<UnknownFailure>());
    });
  });

  group('getTopicPerformance', () {
    test('maps every topic model onto its domain entity', () async {
      when(() => dataSource.getTopicPerformance(filter)).thenAnswer(
        (_) async => const [
          TopicPerformanceModel(
            topicId: 't1',
            topicName: 'Budgeting',
            questionsAttempted: 20,
            answered: 20,
            correct: 18,
            wrong: 2,
          ),
        ],
      );

      final result = await repository.getTopicPerformance(filter: filter);

      expect((result as Success).value, hasLength(1));
    });

    test('maps 401 onto UnauthorizedFailure', () async {
      when(() => dataSource.getTopicPerformance(filter)).thenThrow(
        const ApiException(statusCode: 401, message: 'Authentication required'),
      );

      final result = await repository.getTopicPerformance(filter: filter);

      expect((result as Failure).failure, isA<UnauthorizedFailure>());
    });
  });

  group('getAttempts', () {
    test('forwards limit/offset and maps the page', () async {
      when(() => dataSource.getAttempts(filter, limit: 20, offset: 0))
          .thenAnswer(
            (_) async => AttemptHistoryPageModel(
              items: [
                AttemptSummaryModel(
                  attemptId: 'attempt-1',
                  type: AttemptType.studySession,
                  completedAt: DateTime(2026, 9, 16),
                  contentLabel: 'Budgeting',
                  totalQuestions: 20,
                  answered: 20,
                  correct: 18,
                  scorePercent: 90.0,
                  durationSeconds: 1200,
                ),
              ],
              hasMore: true,
            ),
          );

      final result = await repository.getAttempts(
        filter: filter,
        limit: 20,
        offset: 0,
      );

      final page = (result as Success).value;
      expect(page.items, hasLength(1));
      expect(page.hasMore, isTrue);
    });

    test('maps 500 onto ServerFailure', () async {
      when(() => dataSource.getAttempts(filter, limit: 20, offset: 0))
          .thenThrow(
            const ApiException(statusCode: 500, message: 'Internal error'),
          );

      final result = await repository.getAttempts(filter: filter);

      expect((result as Failure).failure, isA<ServerFailure>());
    });
  });

  group('getAttemptDetails', () {
    test('maps the model onto the domain entity', () async {
      when(() => dataSource.getAttemptDetails('attempt-1')).thenAnswer(
        (_) async => AttemptDetailsModel(
          summary: AttemptSummaryModel(
            attemptId: 'attempt-1',
            type: AttemptType.studySession,
            completedAt: DateTime(2026, 9, 16),
            contentLabel: 'Budgeting',
            totalQuestions: 20,
            answered: 20,
            correct: 18,
            scorePercent: 90.0,
            durationSeconds: 1200,
          ),
          unanswered: 0,
          wrong: 2,
          averageTimePerQuestionSeconds: 60,
        ),
      );

      final result = await repository.getAttemptDetails('attempt-1');

      expect((result as Success).value.summary.attemptId, 'attempt-1');
    });

    test(
      'maps a data-source error (e.g. unknown attemptId) onto UnknownFailure',
      () async {
        when(() => dataSource.getAttemptDetails('missing'))
            .thenThrow(StateError('Unknown mock attempt: missing'));

        final result = await repository.getAttemptDetails('missing');

        expect((result as Failure).failure, isA<UnknownFailure>());
      },
    );
  });
}
