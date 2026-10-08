import '../../../../core/network/api_client.dart';
import '../../domain/entities/session_config.dart';
import '../models/question_feedback_model.dart';
import '../models/question_review_item_model.dart';
import '../models/session_result_model.dart';
import '../models/study_session_bundle_model.dart';
import 'study_session_data_source.dart';

/// Talks to the Study Session endpoints proposed in
/// STUDY_SESSION_API_REQUIREMENTS.md (mobile/ root).
///
/// ⚠️ NOT YET INTEGRATION-TESTED AGAINST A REAL BACKEND — as of Phase 4,
/// backend/ has no Study Session or Question Bank module (verified by
/// inspection). This class exists so the mobile app's abstraction is ready
/// the day those endpoints ship; until then it is wired up but not
/// selected by default — see AppConfig.isStudySessionApiAvailable.
class StudySessionRemoteDataSource implements StudySessionDataSource {
  StudySessionRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<StudySessionBundleModel> startSession(SessionConfig config) {
    return _apiClient.post(
      '/study-sessions',
      data: {
        'topicId': config.topicId,
        'questionCount': config.questionCount,
        'order': config.order.name, // "original" | "random"
        'feedbackMode': config.feedbackMode.name, // "immediate" | "atEnd"
      },
      parse: (data) =>
          StudySessionBundleModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<QuestionFeedbackModel> submitAnswer({
    required String sessionId,
    required String questionId,
    String? selectedChoiceId,
  }) {
    return _apiClient.post(
      '/study-sessions/$sessionId/answers',
      data: {'questionId': questionId, 'selectedChoiceId': selectedChoiceId},
      parse: (data) =>
          QuestionFeedbackModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<SessionResultModel> submitSession({
    required String sessionId,
    required Map<String, String?> answers,
    required Duration totalTime,
  }) {
    return _apiClient.post(
      '/study-sessions/$sessionId/submit',
      data: {'answers': answers, 'totalTimeSeconds': totalTime.inSeconds},
      parse: (data) =>
          SessionResultModel.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<List<QuestionReviewItemModel>> getReview(String sessionId) {
    return _apiClient.get(
      '/study-sessions/$sessionId/review',
      parse: (data) => (data as List)
          .map(
            (json) =>
                QuestionReviewItemModel.fromJson(json as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}
