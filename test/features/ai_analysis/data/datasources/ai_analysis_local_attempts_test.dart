import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_analysis/data/datasources/ai_analysis_data_source.dart';
import 'package:mobile/features/ai_analysis/data/datasources/ai_analysis_mock_data_source.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/performance/data/datasources/performance_mock_data_source.dart';
import 'package:mobile/features/performance/data/local_attempts_provider.dart';
import 'package:mobile/features/performance/data/models/local_attempt_record.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';

import '../../../performance/local_attempt_test_data.dart';

/// Phase 13: AI Analysis needs no changes of its own — its mock already
/// derives everything from PerformanceRepository, so local attempts reach
/// it through Performance. These tests pin that down.
void main() {
  AiAnalysisMockDataSource aiOver(List<LocalAttemptRecord> local) =>
      AiAnalysisMockDataSource(
        PerformanceRepositoryImpl(
          PerformanceMockDataSource(localAttempts: local),
        ),
      );

  test('overall analysis counts a newly recorded attempt', () async {
    final before = await aiOver(const [])
        .getOverallAnalysis(const PerformanceFilter(), languageCode: 'en');
    final after = await aiOver([studyRecord()])
        .getOverallAnalysis(const PerformanceFilter(), languageCode: 'en');

    expect(before.metadata.basedOnAttemptCount, 6);
    expect(after.metadata.basedOnAttemptCount, 7);
    expect(after.overallSummary, contains('7 attempts'));
  });

  test('topic analysis works for a topic only practiced locally', () async {
    final ai = aiOver([
      studyRecord(
        id: 'm1',
        topicId: 'topic-master-budget',
        topicName: 'Master Budget',
        total: 10,
        answered: 10,
        correct: 9,
      ),
    ]);

    final analysis = await ai.getTopicAnalysis(
      'topic-master-budget',
      languageCode: 'en',
    );

    expect(analysis.metadata.scope, AiAnalysisScope.topic);
    expect(analysis.overallSummary, contains('Master Budget'));
    expect(analysis.strengths, isNotEmpty, reason: '90% is a strong topic');
  });

  test('attempt analysis works for a locally generated attempt id', () async {
    final ai = aiOver([studyRecord(id: 'local-mock-session-0-123')]);

    final analysis = await ai.getAttemptAnalysis(
      'local-mock-session-0-123',
      languageCode: 'ar',
    );

    expect(analysis.metadata.attemptId, 'local-mock-session-0-123');
    expect(analysis.topicInsights.single.topicId, 'topic-variance-analysis');
  });

  test('the provider chain rebuilds AI Analysis when an attempt is recorded '
      '(no duplicate AI data source)', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = container.read(aiAnalysisDataSourceProvider);

    // Simulates what the recorder produces, without auth: write straight
    // into the state the Performance data source watches.
    container.read(localAttemptsProvider.notifier).state = [studyRecord()];
    final after = container.read(aiAnalysisDataSourceProvider);

    expect(identical(before, after), isFalse);
    final analysis = await after.getOverallAnalysis(
      const PerformanceFilter(),
      languageCode: 'en',
    );
    expect(analysis.metadata.basedOnAttemptCount, 7);
  });
}
