import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/exam_config.dart';
import '../models/exam_attempt_model.dart';
import '../models/exam_result_model.dart';
import '../models/exam_review_item_model.dart';
import 'exam_mock_data_source.dart';
import 'exam_remote_data_source.dart';

/// Shape both [ExamRemoteDataSource] (real backend, once it exists — see
/// EXAM_SIMULATION_API_REQUIREMENTS.md) and [ExamMockDataSource] (local
/// sample exam, used until then) implement. ExamRepositoryImpl depends on
/// this interface, not on either concrete implementation — mirrors
/// study_session_data_source.dart exactly.
abstract class ExamDataSource {
  Future<ExamAttemptModel> startExam(ExamConfig config);

  Future<ExamAttemptModel> getAttempt(String attemptId);

  Future<ExamResultModel> submitExam({
    required String attemptId,
    required Map<String, String?> answers,
    required Set<String> flaggedQuestionIds,
    required Duration timeTaken,
  });

  Future<List<ExamReviewItemModel>> getReview(String attemptId);
}

/// The single switch between real and sample Exam Simulation data. See
/// AppConfig.isExamSimulationApiAvailable and
/// EXAM_SIMULATION_API_REQUIREMENTS.md — flipping the
/// `EXAM_SIMULATION_API_AVAILABLE` dart-define is the only change needed
/// once the backend ships these endpoints.
final examDataSourceProvider = Provider<ExamDataSource>((ref) {
  if (AppConfig.isExamSimulationApiAvailable) {
    return ExamRemoteDataSource(ref.watch(apiClientProvider));
  }
  return ExamMockDataSource();
});
