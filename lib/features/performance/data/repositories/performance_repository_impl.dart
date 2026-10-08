import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/attempt_details.dart';
import '../../domain/entities/attempt_history_page.dart';
import '../../domain/entities/performance_filter.dart';
import '../../domain/entities/performance_overview.dart';
import '../../domain/entities/topic_performance.dart';
import '../../domain/repositories/performance_repository.dart';
import '../datasources/performance_data_source.dart';

class PerformanceRepositoryImpl implements PerformanceRepository {
  PerformanceRepositoryImpl(this._dataSource);

  final PerformanceDataSource _dataSource;

  @override
  Future<Result<PerformanceOverview>> getOverview({
    PerformanceFilter filter = const PerformanceFilter(),
  }) => _guard(() async => (await _dataSource.getOverview(filter)).toEntity());

  @override
  Future<Result<List<TopicPerformance>>> getTopicPerformance({
    PerformanceFilter filter = const PerformanceFilter(),
  }) => _guard(
    () async =>
        (await _dataSource.getTopicPerformance(filter))
            .map((m) => m.toEntity())
            .toList(),
  );

  @override
  Future<Result<AttemptHistoryPage>> getAttempts({
    PerformanceFilter filter = const PerformanceFilter(),
    int limit = 20,
    int offset = 0,
  }) => _guard(
    () async => (await _dataSource.getAttempts(
      filter,
      limit: limit,
      offset: offset,
    )).toEntity(),
  );

  @override
  Future<Result<AttemptDetails>> getAttemptDetails(String attemptId) => _guard(
    () async => (await _dataSource.getAttemptDetails(attemptId)).toEntity(),
  );

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (error) {
      return Result.failure(mapApiExceptionToFailure(error));
    } catch (error) {
      // Malformed/unexpected response shape, or a mock-data inconsistency
      // (e.g. unknown attemptId) — never let a raw exception reach the UI.
      return const Result.failure(UnknownFailure());
    }
  }
}

final performanceRepositoryProvider = Provider<PerformanceRepository>((ref) {
  return PerformanceRepositoryImpl(ref.watch(performanceDataSourceProvider));
});
