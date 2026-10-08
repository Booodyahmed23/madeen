import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../performance/domain/entities/performance_filter.dart';
import '../../domain/entities/ai_analysis.dart';
import '../../domain/repositories/ai_analysis_repository.dart';
import '../datasources/ai_analysis_data_source.dart';

class AiAnalysisRepositoryImpl implements AiAnalysisRepository {
  AiAnalysisRepositoryImpl(this._dataSource);

  final AiAnalysisDataSource _dataSource;

  @override
  Future<Result<AiAnalysis>> getOverallAnalysis({
    PerformanceFilter filter = const PerformanceFilter(),
    required String languageCode,
  }) => _guard(
    () async => (await _dataSource.getOverallAnalysis(
      filter,
      languageCode: languageCode,
    )).toEntity(),
  );

  @override
  Future<Result<AiAnalysis>> getTopicAnalysis({
    required String topicId,
    required String languageCode,
  }) => _guard(
    () async => (await _dataSource.getTopicAnalysis(
      topicId,
      languageCode: languageCode,
    )).toEntity(),
  );

  @override
  Future<Result<AiAnalysis>> getAttemptAnalysis({
    required String attemptId,
    required String languageCode,
  }) => _guard(
    () async => (await _dataSource.getAttemptAnalysis(
      attemptId,
      languageCode: languageCode,
    )).toEntity(),
  );

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (error) {
      return Result.failure(mapApiExceptionToFailure(error));
    } catch (error) {
      // Malformed/unexpected response shape, or a mock-data inconsistency
      // (e.g. unknown topicId/attemptId) — never let a raw exception reach
      // the UI, same rule as PerformanceRepositoryImpl.
      return const Result.failure(UnknownFailure());
    }
  }
}

final aiAnalysisRepositoryProvider = Provider<AiAnalysisRepository>((ref) {
  return AiAnalysisRepositoryImpl(ref.watch(aiAnalysisDataSourceProvider));
});
