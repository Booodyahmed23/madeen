import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paginated.dart';
import '../../domain/entities/exam_attempt.dart';
import '../../domain/entities/exam_config.dart';
import '../../domain/repositories/exam_repository.dart';
import '../datasources/exam_data_source.dart';
import '../models/exam_attempt_model.dart';

class ExamRepositoryImpl implements ExamRepository {
  ExamRepositoryImpl(this._dataSource);

  final ExamDataSource _dataSource;

  @override
  Future<Result<ExamAttempt>> startExam(ExamConfig config) =>
      _attempt(() => _dataSource.startExam(config));

  @override
  Future<Result<ExamAttempt>> getAttempt(String attemptId) =>
      _attempt(() => _dataSource.getAttempt(attemptId));

  @override
  Future<Result<Paginated<ExamAttemptSummary>>> listAttempts({
    int page = 1,
    int limit = 20,
  }) => _guard(
    () async => Paginated.fromJson(
      await _dataSource.listAttempts(page: page, limit: limit),
      examAttemptSummaryFromJson,
    ),
  );

  @override
  Future<Result<ExamAttempt>> answerQuestion({
    required String attemptId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  }) => _attempt(
    () => _dataSource.answerQuestion(
      attemptId: attemptId,
      questionId: questionId,
      choiceId: choiceId,
      timeSpentSeconds: timeSpentSeconds?.clamp(0, 3600),
    ),
  );

  @override
  Future<Result<ExamAttempt>> flagQuestion({
    required String attemptId,
    required String questionId,
    required bool flagged,
  }) => _attempt(
    () => _dataSource.flagQuestion(
      attemptId: attemptId,
      questionId: questionId,
      flagged: flagged,
    ),
  );

  @override
  Future<Result<ExamAttempt>> submitExam(String attemptId) =>
      _attempt(() => _dataSource.submitExam(attemptId));

  Future<Result<ExamAttempt>> _attempt(Future<Json> Function() call) =>
      _guard(() async => examAttemptFromJson(await call()));

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (error) {
      return Result.failure(mapApiExceptionToFailure(error));
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }
}

final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepositoryImpl(ref.watch(examDataSourceProvider));
});
