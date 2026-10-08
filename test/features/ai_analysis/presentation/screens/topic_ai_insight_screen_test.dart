import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_topic_insight.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/ai_analysis/presentation/screens/topic_ai_insight_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAiAnalysisRepository extends Mock implements AiAnalysisRepository {}

final _topicAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.topic,
    status: AiAnalysisStatus.ready,
    generatedAt: DateTime(2026, 9, 16, 9),
    topicId: 'topic-budgeting',
  ),
  overallSummary: 'Your performance in Budgeting is strong, at 90% accuracy.',
  topicInsights: const [
    AiTopicInsight(
      topicId: 'topic-budgeting',
      topicName: 'Budgeting',
      accuracyPercent: 90,
      answered: 20,
      correct: 18,
      interpretation:
          'Your recent results suggest a solid grasp of this topic.',
      recommendedAction: 'Keep reinforcing Budgeting with occasional practice.',
    ),
  ],
);

Widget _wrap(AiAnalysisRepository repository) {
  return ProviderScope(
    overrides: [aiAnalysisRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const TopicAiInsightScreen(
        topicId: 'topic-budgeting',
        topicName: 'Budgeting',
      ),
    ),
  );
}

void main() {
  testWidgets(
    'renders factual metrics, AI insight, why-this-matters and recommended action',
    (tester) async {
      final repository = MockAiAnalysisRepository();
      when(
        () => repository.getTopicAnalysis(
          topicId: 'topic-budgeting',
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_topicAnalysis));

      await tester.pumpWidget(_wrap(repository));
      await tester.pumpAndSettle();

      expect(find.text('90%'), findsOneWidget);
      expect(
        find.text('Your performance in Budgeting is strong, at 90% accuracy.'),
        findsOneWidget,
      );
      expect(
        find.text('Your recent results suggest a solid grasp of this topic.'),
        findsOneWidget,
      );
      expect(
        find.text('Keep reinforcing Budgeting with occasional practice.'),
        findsOneWidget,
      );
    },
  );
}
