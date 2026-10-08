import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/ai_analysis/data/datasources/ai_analysis_data_source.dart';
import 'package:mobile/features/ai_analysis/data/models/ai_analysis_metadata_model.dart';
import 'package:mobile/features/ai_analysis/data/models/ai_analysis_model.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mocktail/mocktail.dart';

class MockAiAnalysisDataSource extends Mock implements AiAnalysisDataSource {}

void main() {
  late MockAiAnalysisDataSource dataSource;
  late AiAnalysisRepositoryImpl repository;

  const filter = PerformanceFilter();

  setUpAll(() {
    registerFallbackValue(filter);
  });

  setUp(() {
    dataSource = MockAiAnalysisDataSource();
    repository = AiAnalysisRepositoryImpl(dataSource);
  });

  group('getOverallAnalysis', () {
    test('maps the model onto the domain entity', () async {
      when(() => dataSource.getOverallAnalysis(filter, languageCode: 'en'))
          .thenAnswer(
            (_) async => AiAnalysisModel(
              metadata: AiAnalysisMetadataModel(
                scope: AiAnalysisScope.overall,
                status: AiAnalysisStatus.ready,
                generatedAt: DateTime(2026, 9, 16, 9),
                basedOnAttemptCount: 6,
              ),
              overallSummary: 'Summary.',
            ),
          );

      final result = await repository.getOverallAnalysis(
        filter: filter,
        languageCode: 'en',
      );

      expect((result as Success).value.overallSummary, 'Summary.');
    });

    test('maps a network failure onto NetworkFailure', () async {
      when(() => dataSource.getOverallAnalysis(filter, languageCode: 'en'))
          .thenThrow(const ApiException(statusCode: 0, message: 'offline'));

      final result = await repository.getOverallAnalysis(
        filter: filter,
        languageCode: 'en',
      );

      expect((result as Failure).failure, isA<NetworkFailure>());
    });

    test('maps an unexpected error onto UnknownFailure', () async {
      when(() => dataSource.getOverallAnalysis(filter, languageCode: 'en'))
          .thenThrow(StateError('boom'));

      final result = await repository.getOverallAnalysis(
        filter: filter,
        languageCode: 'en',
      );

      expect((result as Failure).failure, isA<UnknownFailure>());
    });
  });

  group('getTopicAnalysis', () {
    test('maps the model onto the domain entity', () async {
      when(() => dataSource.getTopicAnalysis('t1', languageCode: 'en'))
          .thenAnswer(
            (_) async => AiAnalysisModel(
              metadata: AiAnalysisMetadataModel(
                scope: AiAnalysisScope.topic,
                status: AiAnalysisStatus.ready,
                generatedAt: DateTime(2026, 9, 16, 9),
                topicId: 't1',
              ),
              overallSummary: 'Topic summary.',
            ),
          );

      final result = await repository.getTopicAnalysis(
        topicId: 't1',
        languageCode: 'en',
      );

      expect((result as Success).value.metadata.topicId, 't1');
    });

    test('maps an unknown-topicId error onto UnknownFailure', () async {
      when(() => dataSource.getTopicAnalysis('missing', languageCode: 'en'))
          .thenThrow(StateError('Unknown mock topic: missing'));

      final result = await repository.getTopicAnalysis(
        topicId: 'missing',
        languageCode: 'en',
      );

      expect((result as Failure).failure, isA<UnknownFailure>());
    });
  });

  group('getAttemptAnalysis', () {
    test('maps the model onto the domain entity', () async {
      when(() => dataSource.getAttemptAnalysis('a1', languageCode: 'en'))
          .thenAnswer(
            (_) async => AiAnalysisModel(
              metadata: AiAnalysisMetadataModel(
                scope: AiAnalysisScope.attempt,
                status: AiAnalysisStatus.ready,
                generatedAt: DateTime(2026, 9, 16, 9),
                attemptId: 'a1',
              ),
              overallSummary: 'Attempt summary.',
            ),
          );

      final result = await repository.getAttemptAnalysis(
        attemptId: 'a1',
        languageCode: 'en',
      );

      expect((result as Success).value.metadata.attemptId, 'a1');
    });

    test('maps a 401 onto UnauthorizedFailure', () async {
      when(
        () => dataSource.getAttemptAnalysis('a1', languageCode: 'en'),
      ).thenThrow(
        const ApiException(statusCode: 401, message: 'Authentication required'),
      );

      final result = await repository.getAttemptAnalysis(
        attemptId: 'a1',
        languageCode: 'en',
      );

      expect((result as Failure).failure, isA<UnauthorizedFailure>());
    });
  });
}
