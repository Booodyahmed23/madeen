import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../performance/presentation/providers/performance_filter_provider.dart';
import '../../data/repositories/ai_analysis_repository_impl.dart';
import '../../domain/entities/ai_analysis.dart';
import 'ai_analysis_language_provider.dart';

/// Re-fetches whenever the shared `performanceFilterProvider` (attemptType)
/// or the effective language changes — same reactive pattern as
/// performance_providers.dart's `performanceOverviewProvider`, keeping this
/// screen in sync with whatever scope Performance Overview is currently
/// showing.
final overallAiAnalysisProvider = FutureProvider.autoDispose<AiAnalysis>((
  ref,
) async {
  final filter = ref.watch(performanceFilterProvider);
  final languageCode = ref.watch(aiAnalysisLanguageProvider);
  final result = await ref
      .watch(aiAnalysisRepositoryProvider)
      .getOverallAnalysis(filter: filter, languageCode: languageCode);
  return _unwrap(result);
});

/// One topic's AI analysis, cached per `topicId` — mirrors
/// performance_providers.dart's `attemptDetailsProvider` family-caching
/// pattern exactly.
final topicAiAnalysisProvider = FutureProvider.family
    .autoDispose<AiAnalysis, String>((ref, topicId) async {
      final languageCode = ref.watch(aiAnalysisLanguageProvider);
      final result = await ref
          .watch(aiAnalysisRepositoryProvider)
          .getTopicAnalysis(topicId: topicId, languageCode: languageCode);
      return _unwrap(result);
    });

/// One attempt's AI analysis, cached per `attemptId`.
final attemptAiAnalysisProvider = FutureProvider.family
    .autoDispose<AiAnalysis, String>((ref, attemptId) async {
      final languageCode = ref.watch(aiAnalysisLanguageProvider);
      final result = await ref
          .watch(aiAnalysisRepositoryProvider)
          .getAttemptAnalysis(attemptId: attemptId, languageCode: languageCode);
      return _unwrap(result);
    });

/// `FutureProvider` wants a thrown error for its `AsyncError` state, not a
/// `Result.failure` — same seam as performance_providers.dart's `_unwrap`.
T _unwrap<T>(Result<T> result) {
  return result.when(
    success: (value) => value,
    failure: (failure) => throw failure,
  );
}
