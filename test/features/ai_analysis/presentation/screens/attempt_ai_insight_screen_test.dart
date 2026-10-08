import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_insight.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_recommendation.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/ai_analysis/presentation/screens/attempt_ai_insight_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAiAnalysisRepository extends Mock implements AiAnalysisRepository {}

final _attemptAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.attempt,
    status: AiAnalysisStatus.ready,
    generatedAt: DateTime(2026, 9, 16, 9),
    attemptId: 'perf-attempt-2',
  ),
  overallSummary:
      'This Exam Simulation attempt on CMA Part 1 finished at 78% accuracy '
      'across 74 answered questions.',
  recurringPatterns: const [
    AiInsight(
      kind: AiInsightKind.pattern,
      text: '16 of your answers on this attempt were incorrect.',
    ),
  ],
  recommendations: const [
    AiRecommendation(text: 'Review the answers you missed on this attempt.'),
  ],
);

Widget _wrap(AiAnalysisRepository repository) {
  return ProviderScope(
    overrides: [aiAnalysisRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AttemptAiInsightScreen(attemptId: 'perf-attempt-2'),
    ),
  );
}

void main() {
  testWidgets(
    'renders the AI summary, recurring patterns and recommendations',
    (tester) async {
      final repository = MockAiAnalysisRepository();
      when(
        () => repository.getAttemptAnalysis(
          attemptId: 'perf-attempt-2',
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_attemptAnalysis));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'This Exam Simulation attempt on CMA Part 1 finished at 78% accuracy '
          'across 74 answered questions.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('16 of your answers on this attempt were incorrect.'),
        findsOneWidget,
      );
      expect(
        find.text('Review the answers you missed on this attempt.'),
        findsOneWidget,
      );
    },
  );
}
