import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/question_feedback.dart';
import '../../domain/entities/question_review_item.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/session_result.dart';
import '../../domain/entities/study_session_bundle.dart';
import '../../domain/repositories/study_session_repository.dart';
import '../datasources/study_session_data_source.dart';

class StudySessionRepositoryImpl implements StudySessionRepository {
  StudySessionRepositoryImpl(this._dataSource);

  final StudySessionDataSource _dataSource;

  @override
  Future<Result<StudySessionBundle>> startSession(SessionConfig config) =>
      _guard(() async => (await _dataSource.startSession(config)).toEntity());

  @override
  Future<Result<QuestionFeedback>> submitAnswer({
    required String sessionId,
    required String questionId,
    String? selectedChoiceId,
  }) => _guard(
    () async => (await _dataSource.submitAnswer(
      sessionId: sessionId,
      questionId: questionId,
      selectedChoiceId: selectedChoiceId,
    )).toEntity(),
  );

  @override
  Future<Result<SessionResult>> submitSession({
    required String sessionId,
    required Map<String, String?> answers,
    required Duration totalTime,
  }) => _guard(
    () async => (await _dataSource.submitSession(
      sessionId: sessionId,
      answers: answers,
      totalTime: totalTime,
    )).toEntity(),
  );

  @override
  Future<Result<List<QuestionReviewItem>>> getReview(String sessionId) =>
      _guard(
        () async =>
            (await _dataSource.getReview(sessionId))
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
      // (e.g. unknown sessionId) — never let a raw exception reach the UI.
      return const Result.failure(UnknownFailure());
    }
  }
}

final studySessionRepositoryProvider = Provider<StudySessionRepository>((ref) {
  return StudySessionRepositoryImpl(ref.watch(studySessionDataSourceProvider));
});
