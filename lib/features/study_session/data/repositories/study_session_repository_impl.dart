import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paginated.dart';
import '../../domain/entities/session_config.dart';
import '../../domain/entities/study_session.dart';
import '../../domain/repositories/study_session_repository.dart';
import '../datasources/study_session_data_source.dart';
import '../models/study_session_model.dart';

class StudySessionRepositoryImpl implements StudySessionRepository {
  StudySessionRepositoryImpl(this._dataSource);

  final StudySessionDataSource _dataSource;

  @override
  Future<Result<StudySession>> startSession(SessionConfig config) =>
      _session(() => _dataSource.startSession(config));

  @override
  Future<Result<StudySession>> getSession(String sessionId) =>
      _session(() => _dataSource.getSession(sessionId));

  @override
  Future<Result<Paginated<StudySessionSummary>>> listSessions({
    int page = 1,
    int limit = 20,
  }) => _guard(
    () async => Paginated.fromJson(
      await _dataSource.listSessions(page: page, limit: limit),
      studySessionSummaryFromJson,
    ),
  );

  @override
  Future<Result<StudySession>> answerQuestion({
    required String sessionId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  }) => _session(
    () => _dataSource.answerQuestion(
      sessionId: sessionId,
      questionId: questionId,
      choiceId: choiceId,
      timeSpentSeconds: timeSpentSeconds?.clamp(0, 3600),
    ),
  );

  @override
  Future<Result<StudySession>> flagQuestion({
    required String sessionId,
    required String questionId,
    required bool flagged,
  }) => _session(
    () => _dataSource.flagQuestion(
      sessionId: sessionId,
      questionId: questionId,
      flagged: flagged,
    ),
  );

  @override
  Future<Result<StudySession>> pauseSession(String sessionId) =>
      _session(() => _dataSource.pauseSession(sessionId));

  @override
  Future<Result<StudySession>> resumeSession(String sessionId) =>
      _session(() => _dataSource.resumeSession(sessionId));

  @override
  Future<Result<StudySession>> completeSession(String sessionId) async {
    final result = await _session(() => _dataSource.completeSession(sessionId));
    if (result is Failure<StudySession> &&
        result.failure is ValidationFailure) {
      // `400` "already completed" — e.g. a retry after the first response
      // was lost. Continue with the session as the server has it.
      final current = await getSession(sessionId);
      if (current case Success(:final value) when value.isCompleted) {
        return current;
      }
    }
    return result;
  }

  Future<Result<StudySession>> _session(Future<Json> Function() call) =>
      _guard(() async => studySessionFromJson(await call()));

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (error) {
      return Result.failure(mapApiExceptionToFailure(error));
    } catch (_) {
      // Malformed/unexpected response shape — never let a raw exception
      // reach the UI.
      return const Result.failure(UnknownFailure());
    }
  }
}

final studySessionRepositoryProvider = Provider<StudySessionRepository>((ref) {
  return StudySessionRepositoryImpl(ref.watch(studySessionDataSourceProvider));
});
