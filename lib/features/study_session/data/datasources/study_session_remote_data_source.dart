import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated.dart';
import '../../domain/entities/session_config.dart';
import '../models/study_session_model.dart';
import 'study_session_data_source.dart';

/// `/study/sessions/*` (contract §A3). Sends only the documented fields —
/// the API rejects unknown ones with `400` (§G4).
class StudySessionRemoteDataSource implements StudySessionDataSource {
  StudySessionRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static const _base = '/study/sessions';

  static Json _json(dynamic data) => data as Json;

  @override
  Future<Json> startSession(SessionConfig config) => _apiClient.post(
    _base,
    data: {
      // Omitted for "all my topics".
      if (config.topicIds.isNotEmpty) 'topicIds': config.topicIds,
      'questionCount': config.questionCount,
      'feedbackMode': feedbackModeToWire(config.feedbackMode),
      'difficulty': ?config.difficulty?.toWire(),
    },
    parse: _json,
  );

  @override
  Future<Json> getSession(String sessionId) =>
      _apiClient.get('$_base/$sessionId', parse: _json);

  @override
  Future<Json> listSessions({required int page, required int limit}) =>
      _apiClient.get(
        _base,
        queryParameters: pageQuery(page: page, limit: limit),
        parse: _json,
      );

  @override
  Future<Json> answerQuestion({
    required String sessionId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  }) => _apiClient.patch(
    '$_base/$sessionId/questions/$questionId/answer',
    data: {'choiceId': choiceId, 'timeSpentSeconds': ?timeSpentSeconds},
    parse: _json,
  );

  @override
  Future<Json> flagQuestion({
    required String sessionId,
    required String questionId,
    required bool flagged,
  }) => _apiClient.patch(
    '$_base/$sessionId/questions/$questionId/flag',
    data: {'flagged': flagged},
    parse: _json,
  );

  @override
  Future<Json> pauseSession(String sessionId) =>
      _apiClient.patch('$_base/$sessionId/pause', parse: _json);

  @override
  Future<Json> resumeSession(String sessionId) =>
      _apiClient.patch('$_base/$sessionId/resume', parse: _json);

  @override
  Future<Json> completeSession(String sessionId) =>
      _apiClient.post('$_base/$sessionId/complete', parse: _json);
}
