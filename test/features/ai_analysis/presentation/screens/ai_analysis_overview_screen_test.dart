import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_insight.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_recommendation.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_topic_insight.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/ai_analysis/presentation/screens/ai_analysis_overview_screen.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAiAnalysisRepository extends Mock implements AiAnalysisRepository {}

final _readyAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.overall,
    status: AiAnalysisStatus.ready,
    generatedAt: DateTime(2026, 9, 16, 9),
    basedOnAttemptCount: 6,
  ),
  overallSummary: 'Your recent practice across 6 attempts shows 77% accuracy.',
  strengths: const [
    AiInsight(
      kind: AiInsightKind.strength,
      text: 'Strong in Budgeting.',
      topicId: 'topic-budgeting',
      topicName: 'Budgeting',
      supportingMetricPercent: 90,
    ),
  ],
  weaknesses: const [
    AiInsight(
      kind: AiInsightKind.weakness,
      text: 'Needs review in Variance Analysis.',
      topicId: 'topic-variance-analysis',
      topicName: 'Variance Analysis',
      supportingMetricPercent: 55,
    ),
  ],
  topicInsights: const [
    AiTopicInsight(
      topicId: 'topic-budgeting',
      topicName: 'Budgeting',
      accuracyPercent: 90,
      answered: 20,
      correct: 18,
      interpretation: 'Solid grasp of this topic.',
      recommendedAction: 'Keep reinforcing it.',
    ),
  ],
  recommendations: const [
    AiRecommendation(
      text: 'Review Variance Analysis.',
      topicId: 'topic-variance-analysis',
      topicName: 'Variance Analysis',
    ),
  ],
);

final _insufficientAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.overall,
    status: AiAnalysisStatus.insufficientData,
    generatedAt: DateTime(2026, 9, 16, 9),
    basedOnAttemptCount: 0,
  ),
  overallSummary: 'Complete a Study Session to unlock personalized insights.',
);

Widget _wrap(
  AiAnalysisRepository repository, {
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [aiAnalysisRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AiAnalysisOverviewScreen(),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  testWidgets('shows a loading indicator while the analysis is fetched', (
    tester,
  ) async {
    final repository = MockAiAnalysisRepository();
    final completer = Completer<Result<AiAnalysis>>();
    when(
      () => repository.getOverallAnalysis(
        filter: any(named: 'filter'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repository));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);

    completer.complete(Result.success(_insufficientAnalysis));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'shows the empty-state explanation for a student with no attempts',
    (tester) async {
      final repository = MockAiAnalysisRepository();
      when(
        () => repository.getOverallAnalysis(
          filter: any(named: 'filter'),
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_insufficientAnalysis));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(
        find.text('Complete a Study Session to unlock personalized insights.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'renders strengths, weaknesses, topic insights and recommendations',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = MockAiAnalysisRepository();
      when(
        () => repository.getOverallAnalysis(
          filter: any(named: 'filter'),
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_readyAnalysis));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.text('Strong in Budgeting.'), findsOneWidget);
      expect(find.text('Needs review in Variance Analysis.'), findsOneWidget);
      expect(find.text('Budgeting'), findsWidgets);
      expect(find.text('Review Variance Analysis.'), findsOneWidget);
      expect(find.text('Based on your 6 most recent attempts'), findsOneWidget);
    },
  );

  testWidgets('shows a localized error message and a retry button on failure', (
    tester,
  ) async {
    final repository = MockAiAnalysisRepository();
    when(
      () => repository.getOverallAnalysis(
        filter: any(named: 'filter'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Retry'), findsOneWidget);
  });

  testWidgets('retry re-fetches after a failure', (tester) async {
    final repository = MockAiAnalysisRepository();
    var callCount = 0;
    when(
      () => repository.getOverallAnalysis(
        filter: any(named: 'filter'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) return const Result.failure(NetworkFailure());
      return Result.success(_insufficientAnalysis);
    });

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Retry'));
    await tester.pumpAndSettle();

    expect(
      find.text('Complete a Study Session to unlock personalized insights.'),
      findsOneWidget,
    );
    expect(callCount, 2);
  });

  testWidgets('renders in Arabic (RTL) without crashing', (tester) async {
    final repository = MockAiAnalysisRepository();
    when(
      () => repository.getOverallAnalysis(
        filter: any(named: 'filter'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async => Result.success(_readyAnalysis));

    await tester.pumpWidget(_wrap(repository, locale: const Locale('ar')));
    await tester.pumpAndSettle();

    expect(find.text('تحليل الذكاء الاصطناعي'), findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });
}
