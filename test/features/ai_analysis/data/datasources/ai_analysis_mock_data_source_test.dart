import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/ai_analysis/data/datasources/ai_analysis_mock_data_source.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_insight.dart';
import 'package:mobile/features/performance/data/datasources/performance_mock_data_source.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

void main() {
  late AiAnalysisMockDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  setUp(() {
    // Backed by the real PerformanceMockDataSource fixture (six attempts,
    // spanning a strong topic (Budgeting, 90%) and a needs-practice topic
    // (Variance Analysis, 55%)) through the real repository, exactly the
    // composition ai_analysis_data_source.dart's provider wires up — this
    // is what guarantees the AI content this class generates never
    // contradicts what Performance's own screens show for the same data.
    dataSource = AiAnalysisMockDataSource(
      PerformanceRepositoryImpl(PerformanceMockDataSource()),
    );
  });

  group('getOverallAnalysis', () {
    test('is ready and grounded in the Performance mock fixture', () async {
      final model = await dataSource.getOverallAnalysis(
        const PerformanceFilter(),
        languageCode: 'en',
      );

      expect(model.metadata.scope, AiAnalysisScope.overall);
      expect(model.metadata.status, AiAnalysisStatus.ready);
      expect(model.metadata.basedOnAttemptCount, 6);

      // Budgeting (90%) is strong; Variance Analysis (55%) needs practice —
      // see PerformanceMockDataSource's fixture.
      expect(model.strengths, isNotEmpty);
      expect(model.strengths.first.topicName, 'Budgeting');
      expect(model.strengths.first.supportingMetricPercent, 90.0);

      expect(model.weaknesses, isNotEmpty);
      expect(model.weaknesses.first.topicName, 'Variance Analysis');
      expect(
        model.weaknesses.first.supportingMetricPercent,
        closeTo(55.0, 0.001),
      );

      expect(model.topicInsights, hasLength(4));
      expect(model.recommendations, isNotEmpty);
      expect(model.overallSummary, contains('6 attempts'));
    });

    test(
      'reports insufficient data for a student with zero attempts',
      () async {
        // The real mock fixture always has six attempts, so this exercises
        // the insufficient-data path via a stubbed repository instead.
        final emptyRepository = MockPerformanceRepository();
        when(() => emptyRepository.getOverview(filter: any(named: 'filter')))
            .thenAnswer(
              (_) async => const Result.success(
                PerformanceOverview(
                  totalAttempts: 0,
                  questionsPracticed: 0,
                  totalAnswered: 0,
                  totalCorrect: 0,
                  overallScorePercent: 0,
                  totalTime: Duration.zero,
                  averageTimePerQuestion: Duration.zero,
                ),
              ),
            );
        final emptyDataSource = AiAnalysisMockDataSource(emptyRepository);

        final model = await emptyDataSource.getOverallAnalysis(
          const PerformanceFilter(),
          languageCode: 'en',
        );

        expect(model.metadata.status, AiAnalysisStatus.insufficientData);
        expect(model.strengths, isEmpty);
        expect(model.weaknesses, isEmpty);
        expect(model.topicInsights, isEmpty);
        expect(model.recommendations, isEmpty);
      },
    );

    test('never claims a topic strength/weakness that Exam Simulation data cannot support', () async {
      final model = await dataSource.getOverallAnalysis(
        const PerformanceFilter(attemptType: AttemptTypeFilter.examSimulation),
        languageCode: 'en',
      );

      // Exam Simulation attempts carry no topic context (see
      // TopicPerformance's doc comment) — the AI layer must not invent
      // topic-level claims it has no data for.
      expect(model.strengths, isEmpty);
      expect(model.weaknesses, isEmpty);
      expect(model.topicInsights, isEmpty);
    });

    test('returns Arabic copy when languageCode is ar', () async {
      final model = await dataSource.getOverallAnalysis(
        const PerformanceFilter(),
        languageCode: 'ar',
      );

      expect(model.overallSummary, contains('محاولة'));
      expect(model.strengths.first.text, contains('الأخيرة'));
    });
  });

  group('getTopicAnalysis', () {
    test('returns a single topic insight for a strong topic', () async {
      final model = await dataSource.getTopicAnalysis(
        'topic-budgeting',
        languageCode: 'en',
      );

      expect(model.metadata.scope, AiAnalysisScope.topic);
      expect(model.metadata.topicId, 'topic-budgeting');
      expect(model.metadata.basedOnAttemptCount, isNull);
      expect(model.topicInsights, hasLength(1));
      expect(model.topicInsights.single.accuracyPercent, 90.0);
      expect(model.strengths, hasLength(1));
      expect(model.weaknesses, isEmpty);
    });

    test('returns a weakness for a needs-practice topic', () async {
      final model = await dataSource.getTopicAnalysis(
        'topic-variance-analysis',
        languageCode: 'en',
      );

      expect(model.weaknesses, hasLength(1));
      expect(model.strengths, isEmpty);
      expect(model.recommendations, hasLength(1));
      expect(model.recommendations.single.topicId, 'topic-variance-analysis');
    });

    test('throws for an unknown topicId', () {
      expect(
        () => dataSource.getTopicAnalysis('unknown-topic', languageCode: 'en'),
        throwsStateError,
      );
    });
  });

  group('getAttemptAnalysis', () {
    test('grounds the summary in the attempt\'s own numbers', () async {
      final model = await dataSource.getAttemptAnalysis(
        'perf-attempt-1',
        languageCode: 'en',
      );

      expect(model.metadata.scope, AiAnalysisScope.attempt);
      expect(model.metadata.attemptId, 'perf-attempt-1');
      expect(model.overallSummary, contains('90%'));
    });

    test(
      'surfaces a wrong-answers pattern when the attempt has mistakes',
      () async {
        // perf-attempt-2: 80 questions, 74 answered, 58 correct -> 16 wrong,
        // and a 150s/question pace (well above the mock's "typical" pace),
        // so both the wrong-answer and slow-pace patterns should surface —
        // plus, since 6 questions were left unanswered, the unanswered one.
        final model = await dataSource.getAttemptAnalysis(
          'perf-attempt-2',
          languageCode: 'en',
        );

        expect(
          model.recurringPatterns.any((p) => p.kind == AiInsightKind.pattern),
          isTrue,
        );
        expect(model.recurringPatterns, hasLength(3));
        expect(
          model.recurringPatterns.any(
            (p) => p.text.contains('6 question(s) were left unanswered'),
          ),
          isTrue,
        );
      },
    );

    test('throws for an unknown attemptId', () {
      // Unlike getTopicAnalysis's local `firstWhere`, this StateError is
      // raised inside PerformanceMockDataSource.getAttemptDetails and
      // already converted to `UnknownFailure` by PerformanceRepositoryImpl
      // before this class ever sees it — see this class's `_unwrap` doc
      // comment.
      expect(
        () => dataSource.getAttemptAnalysis('unknown', languageCode: 'en'),
        throwsA(isA<UnknownFailure>()),
      );
    });
  });
}
