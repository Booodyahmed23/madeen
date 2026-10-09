import '../../../../core/network/api_client.dart';
import '../../../../core/network/paginated.dart';
import '../../domain/entities/exam_config.dart';
import 'exam_data_source.dart';

/// `/exams/attempts/*` (contract §A4). Sends only the documented fields —
/// the API rejects unknown ones with `400` (§G4).
class ExamRemoteDataSource implements ExamDataSource {
  ExamRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  static const _base = '/exams/attempts';

  static Json _json(dynamic data) => data as Json;

  @override
  Future<Json> startExam(ExamConfig config) => _apiClient.post(
    _base,
    data: {
      'topicIds': config.topicIds,
      'questionCount': config.questionCount,
      'durationMinutes': config.durationMinutes,
      'difficulty': ?config.difficulty?.toWire(),
    },
    parse: _json,
  );

  @override
  Future<Json> getAttempt(String attemptId) =>
      _apiClient.get('$_base/$attemptId', parse: _json);

  @override
  Future<Json> listAttempts({required int page, required int limit}) =>
      _apiClient.get(
        _base,
        queryParameters: pageQuery(page: page, limit: limit),
        parse: _json,
      );

  @override
  Future<Json> answerQuestion({
    required String attemptId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  }) => _apiClient.patch(
    '$_base/$attemptId/questions/$questionId/answer',
    data: {'choiceId': choiceId, 'timeSpentSeconds': ?timeSpentSeconds},
    parse: _json,
  );

  @override
  Future<Json> flagQuestion({
    required String attemptId,
    required String questionId,
    required bool flagged,
  }) => _apiClient.patch(
    '$_base/$attemptId/questions/$questionId/flag',
    data: {'flagged': flagged},
    parse: _json,
  );

  @override
  Future<Json> submitExam(String attemptId) =>
      _apiClient.post('$_base/$attemptId/submit', parse: _json);
}
