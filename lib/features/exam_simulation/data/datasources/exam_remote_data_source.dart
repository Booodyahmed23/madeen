import '../../../../core/network/api_client.dart';
import '../../domain/entities/exam_config.dart';
import '../models/exam_attempt_model.dart';
import '../models/exam_result_model.dart';
import '../models/exam_review_item_model.dart';
import 'exam_data_source.dart';

/// Talks to the Exam Simulation endpoints proposed in
/// EXAM_SIMULATION_API_REQUIREMENTS.md (mobile/ root).
///
/// ⚠️ NOT YET INTEGRATION-TESTED AGAINST A REAL BACKEND — as of Phase 5,
/// backend/ has no Exam Simulation module (verified by inspection). This
/// class exists so the mobile app's abstraction is ready the day those
/// endpoints ship; until then it is wired up but not selected by default —
/// see AppConfig.isExamSimulationApiAvailable.
class ExamRemoteDataSource implements ExamDataSource {
  ExamRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<ExamAttemptModel> startExam(ExamConfig config) {
    return _apiClient.post(
      '/exam-attempts',
      data: {
        'programId': config.programId,
        'partId': config.partId,
        'unitId': config.unitId,
        'subUnitId': config.subUnitId,
        'questionCount': config.questionCount,
        'questionOrder': config.questionOrder.toWire(),
        'durationSeconds': config.duration.inSeconds,
      },
      parse: (data) => ExamAttemptModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<ExamAttemptModel> getAttempt(String attemptId) {
    return _apiClient.get(
      '/exam-attempts/$attemptId',
      parse: (data) => ExamAttemptModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<ExamResultModel> submitExam({
    required String attemptId,
    required Map<String, String?> answers,
    required Set<String> flaggedQuestionIds,
    required Duration timeTaken,
  }) {
    return _apiClient.post(
      '/exam-attempts/$attemptId/submit',
      data: {
        'answers': answers,
        'flaggedQuestionIds': flaggedQuestionIds.toList(),
        'timeTakenSeconds': timeTaken.inSeconds,
      },
      parse: (data) => ExamResultModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<List<ExamReviewItemModel>> getReview(String attemptId) {
    return _apiClient.get(
      '/exam-attempts/$attemptId/review',
      parse: (data) => (data as List)
          .map(
            (json) =>
                ExamReviewItemModel.fromJson(json as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
