import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/exam_attempt.dart';
import '../../domain/entities/exam_config.dart';
import '../../domain/entities/exam_result.dart';
import '../../domain/entities/exam_review_item.dart';
import '../../domain/repositories/exam_repository.dart';
import '../datasources/exam_data_source.dart';

class ExamRepositoryImpl implements ExamRepository {
  ExamRepositoryImpl(this._dataSource);

  final ExamDataSource _dataSource;

  @override
  Future<Result<ExamAttempt>> startExam(ExamConfig config) =>
      _guard(() async => (await _dataSource.startExam(config)).toEntity());

  @override
  Future<Result<ExamAttempt>> getAttempt(String attemptId) =>
      _guard(() async => (await _dataSource.getAttempt(attemptId)).toEntity());

  @override
  Future<Result<ExamResult>> submitExam({
    required String attemptId,
    required Map<String, String?> answers,
    required Set<String> flaggedQuestionIds,
    required Duration timeTaken,
  }) => _guard(
    () async => (await _dataSource.submitExam(
      attemptId: attemptId,
      answers: answers,
      flaggedQuestionIds: flaggedQuestionIds,
      timeTaken: timeTaken,
    )).toEntity(),
  );

  @override
  Future<Result<List<ExamReviewItem>>> getReview(String attemptId) => _guard(
    () async =>
        (await _dataSource.getReview(attemptId))
            .map((m) => m.toEntity())
            .toList(),
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

final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepositoryImpl(ref.watch(examDataSourceProvider));
});
