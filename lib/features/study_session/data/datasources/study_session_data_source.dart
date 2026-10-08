import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/session_config.dart';
import 'study_session_mock_data_source.dart';
import 'study_session_remote_data_source.dart';

typedef Json = Map<String, dynamic>;

/// The study endpoints (contract §A3), returning the API's raw JSON — the
/// Session object, or a `{ data, meta }` page for [listSessions]. Both
/// [StudySessionRemoteDataSource] and [StudySessionMockDataSource] produce
/// the same JSON, so one parser (data/models) serves both.
abstract class StudySessionDataSource {
  Future<Json> startSession(SessionConfig config);

  Future<Json> getSession(String sessionId);

  Future<Json> listSessions({required int page, required int limit});

  Future<Json> answerQuestion({
    required String sessionId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  });

  Future<Json> flagQuestion({
    required String sessionId,
    required String questionId,
    required bool flagged,
  });

  Future<Json> pauseSession(String sessionId);

  Future<Json> resumeSession(String sessionId);

  Future<Json> completeSession(String sessionId);
}

/// The single switch between the real API and sample data — the
/// `STUDY_SESSION_API_AVAILABLE` dart-define (see AppConfig).
final studySessionDataSourceProvider = Provider<StudySessionDataSource>((ref) {
  if (AppConfig.isStudySessionApiAvailable) {
    return StudySessionRemoteDataSource(ref.watch(apiClientProvider));
  }
  return StudySessionMockDataSource();
});
