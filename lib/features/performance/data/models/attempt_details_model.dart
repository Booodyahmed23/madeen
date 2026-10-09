import '../../domain/entities/attempt_details.dart';
import 'attempt_summary_model.dart';
import 'topic_performance_model.dart';

class AttemptDetailsModel {
  const AttemptDetailsModel({
    required this.summary,
    required this.unanswered,
    required this.wrong,
    required this.averageTimePerQuestionSeconds,
    this.topics = const [],
  });

  factory AttemptDetailsModel.fromJson(Map<String, dynamic> json) {
    return AttemptDetailsModel(
      summary: AttemptSummaryModel.fromJson(json),
      unanswered: (json['unanswered'] as num).toInt(),
      wrong: (json['wrong'] as num).toInt(),
      averageTimePerQuestionSeconds:
          (json['averageTimePerQuestionSeconds'] as num).toInt(),
      topics: json['topics'] == null
          ? const []
          : (json['topics'] as List)
                .map(
                  (t) =>
                      TopicPerformanceModel.fromJson(t as Map<String, dynamic>),
                )
                .toList(),
    );
  }

  /// The summary fields are flattened into the same JSON object as the
  /// detail-only fields (`unanswered`, `wrong`, ...) — see
  /// docs/MOBILE_API_CONTRACT.md §A5's `GET
  /// /performance/attempts/:attemptId` response shape — so
  /// [AttemptSummaryModel.fromJson] can parse the same map directly.
  final AttemptSummaryModel summary;
  final int unanswered;
  final int wrong;
  final int averageTimePerQuestionSeconds;
  final List<TopicPerformanceModel> topics;

  AttemptDetails toEntity() => AttemptDetails(
    summary: summary.toEntity(),
    unanswered: unanswered,
    wrong: wrong,
    averageTimePerQuestion: Duration(seconds: averageTimePerQuestionSeconds),
    topics: topics.map((t) => t.toEntity()).toList(),
  );
}
