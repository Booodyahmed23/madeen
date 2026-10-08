import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/session_config.dart';
import '../models/question_feedback_model.dart';
import '../models/question_review_item_model.dart';
import '../models/session_result_model.dart';
import '../models/study_session_bundle_model.dart';
import 'study_session_mock_data_source.dart';
import 'study_session_remote_data_source.dart';

/// Shape both [StudySessionRemoteDataSource] (real backend, once it exists
/// — see STUDY_SESSION_API_REQUIREMENTS.md) and [StudySessionMockDataSource]
/// (local sample questions, used until then) implement.
/// StudySessionRepositoryImpl depends on this interface, not on either
/// concrete implementation — mirrors curriculum_data_source.dart exactly.
abstract class StudySessionDataSource {
  Future<StudySessionBundleModel> startSession(SessionConfig config);

  Future<QuestionFeedbackModel> submitAnswer({
    required String sessionId,
    required String questionId,
    String? selectedChoiceId,
  });

  Future<SessionResultModel> submitSession({
    required String sessionId,
    required Map<String, String?> answers,
    required Duration totalTime,
  });

  Future<List<QuestionReviewItemModel>> getReview(String sessionId);
}

/// The single switch between real and sample Study Session data. See
/// AppConfig.isStudySessionApiAvailable and
/// STUDY_SESSION_API_REQUIREMENTS.md — flipping the
/// `STUDY_SESSION_API_AVAILABLE` dart-define is the only change needed once
/// the backend ships these endpoints.
final studySessionDataSourceProvider = Provider<StudySessionDataSource>((ref) {
  if (AppConfig.isStudySessionApiAvailable) {
    return StudySessionRemoteDataSource(ref.watch(apiClientProvider));
  }
  return StudySessionMockDataSource();
});
