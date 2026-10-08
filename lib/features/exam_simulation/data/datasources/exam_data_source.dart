import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/exam_config.dart';
import 'exam_mock_data_source.dart';
import 'exam_remote_data_source.dart';

typedef Json = Map<String, dynamic>;

/// The exam endpoints (contract §A4), returning the API's raw JSON — the
/// Attempt object, or a `{ data, meta }` page for [listAttempts]. Both
/// implementations produce the same JSON, so one parser serves both.
abstract class ExamDataSource {
  Future<Json> startExam(ExamConfig config);

  Future<Json> getAttempt(String attemptId);

  Future<Json> listAttempts({required int page, required int limit});

  Future<Json> answerQuestion({
    required String attemptId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  });

  Future<Json> flagQuestion({
    required String attemptId,
    required String questionId,
    required bool flagged,
  });

  Future<Json> submitExam(String attemptId);
}

/// The single switch between the real API and sample data — the
/// `EXAM_SIMULATION_API_AVAILABLE` dart-define (see AppConfig).
final examDataSourceProvider = Provider<ExamDataSource>((ref) {
  if (AppConfig.isExamSimulationApiAvailable) {
    return ExamRemoteDataSource(ref.watch(apiClientProvider));
  }
  return ExamMockDataSource();
});
