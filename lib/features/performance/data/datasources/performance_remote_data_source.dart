import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/paginated.dart';
import '../../../exam_simulation/data/models/exam_attempt_model.dart';
import '../../../exam_simulation/domain/entities/exam_attempt.dart';
import '../../../study_session/data/models/study_session_model.dart';
import '../../../study_session/domain/entities/study_session.dart';
import '../../domain/entities/attempt_type.dart';
import '../../domain/entities/performance_filter.dart';
import '../../domain/entities/trend_day.dart';
import '../models/attempt_details_model.dart';
import '../models/attempt_history_page_model.dart';
import '../models/attempt_summary_model.dart';
import '../models/performance_overview_model.dart';
import '../models/topic_performance_model.dart';
import 'performance_data_source.dart';

/// Turns an attempt's topic ids into its label (e.g. "Budgeting +2") — the
/// API sends ids only (contract §A5).
typedef TopicsLabeler = Future<String> Function(List<String> topicIds);

/// `/results/*` (contract §A5), plus the attempt itself for details —
/// `GET /study/sessions/:id` or `GET /exams/attempts/:id`, whose public
/// parsers this reads (the same seam as data/mappers).
class PerformanceRemoteDataSource implements PerformanceDataSource {
  PerformanceRemoteDataSource(this._apiClient, {required this.labelTopics});

  final ApiClient _apiClient;
  final TopicsLabeler labelTopics;

  /// `type=STUDY|EXAM`; `all` sends no `type`.
  Map<String, dynamic> _typeQuery(PerformanceFilter filter) {
    return switch (filter.attemptType) {
      AttemptTypeFilter.all => const {},
      AttemptTypeFilter.studySession => {
        'type': AttemptType.studySession.toWire(),
      },
      AttemptTypeFilter.examSimulation => {
        'type': AttemptType.examSimulation.toWire(),
      },
    };
  }

  @override
  Future<PerformanceOverviewModel> getOverview(PerformanceFilter filter) {
    return _apiClient.get(
      '/results/overview',
      queryParameters: _typeQuery(filter),
      parse: (data) {
        final json = data as Map<String, dynamic>;
        return PerformanceOverviewModel(
          totalAttempts: (json['totalAttempts'] as num).toInt(),
          questionsPracticed: (json['questionsPracticed'] as num).toInt(),
          totalAnswered: (json['totalAnswered'] as num).toInt(),
          totalCorrect: (json['totalCorrect'] as num).toInt(),
          overallScorePercent: (json['scorePercent'] as num?)?.toDouble() ?? 0,
          totalTimeSeconds: (json['totalTimeSeconds'] as num).toInt(),
          averageTimePerQuestionSeconds:
              (json['avgTimeSeconds'] as num?)?.round() ?? 0,
        );
      },
    );
  }

  @override
  Future<List<TopicPerformanceModel>> getTopicPerformance(
    PerformanceFilter filter,
  ) {
    return _apiClient.get(
      '/results/performance/topics',
      queryParameters: _typeQuery(filter),
      parse: (data) => [
        for (final item in data as List)
          _performanceEntry(item as Map<String, dynamic>),
      ],
    );
  }

  @override
  Future<List<TopicPerformanceModel>> getPartPerformance(
    PerformanceFilter filter,
  ) {
    return _apiClient.get(
      '/results/performance/parts',
      queryParameters: _typeQuery(filter),
      parse: (data) => [
        for (final item in data as List)
          _performanceEntry(item as Map<String, dynamic>),
      ],
    );
  }

  /// `tzOffsetMinutes` is east of UTC positive (e.g. 180 for UTC+3), so
  /// days split at the student's midnight.
  @override
  Future<List<TrendDay>> getTrend({required int days}) {
    return _apiClient.get(
      '/results/performance/trend',
      queryParameters: {
        'days': days,
        'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      },
      parse: (data) => [
        for (final item in data as List)
          () {
            final json = item as Map<String, dynamic>;
            return TrendDay(
              date: DateTime.parse(json['date'] as String),
              correct: (json['correct'] as num).toInt(),
              total: (json['total'] as num).toInt(),
              accuracyPercent: (json['accuracy'] as num?)?.toDouble(),
            );
          }(),
      ],
    );
  }

  /// `{ id, name, correct, total, accuracy, avgTimeSeconds }`, where
  /// `total` counts revealed answers.
  static TopicPerformanceModel _performanceEntry(Map<String, dynamic> json) {
    final total = (json['total'] as num).toInt();
    final correct = (json['correct'] as num).toInt();
    return TopicPerformanceModel(
      topicId: json['id'] as String,
      topicName: json['name'] as String,
      questionsAttempted: total,
      answered: total,
      correct: correct,
      wrong: total - correct,
      averageTimePerQuestionSeconds: (json['avgTimeSeconds'] as num?)?.round(),
    );
  }

  /// History is paged by `page`/`limit`; [offset] is always a multiple of
  /// [limit] here (the app loads page after page). Unfinished attempts are
  /// left out — Home offers to continue those.
  @override
  Future<AttemptHistoryPageModel> getAttempts(
    PerformanceFilter filter, {
    required int limit,
    required int offset,
  }) async {
    final page = await _apiClient.get(
      '/results/history',
      queryParameters: {
        ...pageQuery(page: offset ~/ limit + 1, limit: limit),
        ..._typeQuery(filter),
      },
      parse: (data) =>
          Paginated.fromJson(data as Map<String, dynamic>, (j) => j),
    );
    final items = <AttemptSummaryModel>[];
    for (final row in page.items) {
      final finalizedAt = row['finalizedAt'] as String?;
      if (finalizedAt == null) continue;
      final requested = (row['requestedCount'] as num).toInt();
      final correct = (row['correctCount'] as num?)?.toInt() ?? 0;
      items.add(
        AttemptSummaryModel(
          attemptId: row['id'] as String,
          type: AttemptType.fromWire(row['type'] as String),
          completedAt: DateTime.parse(finalizedAt),
          contentLabel: await labelTopics(
            (row['topicIds'] as List).cast<String>(),
          ),
          totalQuestions: requested,
          answered: (row['answeredCount'] as num).toInt(),
          correct: correct,
          scorePercent: requested == 0 ? 0 : correct / requested * 100,
          durationSeconds: (row['totalTimeSeconds'] as num?)?.toInt() ?? 0,
        ),
      );
    }
    return AttemptHistoryPageModel(items: items, hasMore: page.hasMore);
  }

  /// The attempt is either a study session or an exam attempt; ids are
  /// UUIDs, so trying one and then the other can't pick the wrong one.
  @override
  Future<AttemptDetailsModel> getAttemptDetails(String attemptId) async {
    try {
      final session = await _apiClient.get(
        '/study/sessions/$attemptId',
        parse: (data) => studySessionFromJson(data as Map<String, dynamic>),
      );
      return _sessionDetails(session, await _labelFor(session.topicIds));
    } on ApiException catch (error) {
      if (error.statusCode != 404) rethrow;
    }
    final attempt = await _apiClient.get(
      '/exams/attempts/$attemptId',
      parse: (data) => examAttemptFromJson(data as Map<String, dynamic>),
    );
    return _attemptDetails(attempt, await _labelFor(attempt.topicIds));
  }

  /// The same label history shows for this attempt.
  Future<String> _labelFor(List<String> topicIds) async {
    try {
      return await labelTopics(topicIds);
    } catch (_) {
      return '';
    }
  }

  AttemptDetailsModel _sessionDetails(StudySession session, String label) {
    if (!session.isCompleted) {
      throw const ApiException(
        statusCode: 404,
        message: 'The session is still in progress.',
      );
    }
    final result = session.toResult();
    return AttemptDetailsModel(
      summary: AttemptSummaryModel(
        attemptId: session.id,
        type: AttemptType.studySession,
        completedAt: session.completedAt ?? session.createdAt,
        contentLabel: label.isNotEmpty
            ? label
            : _label({
                for (final q in session.questions) q.topic.id: q.topic.name,
              }),
        totalQuestions: result.totalQuestions,
        answered: result.answered,
        correct: result.correct,
        scorePercent: result.scorePercent,
        durationSeconds: result.totalTime.inSeconds,
      ),
      unanswered: result.unanswered,
      wrong: result.incorrect,
      averageTimePerQuestionSeconds: result.averageTimePerQuestion.inSeconds,
      topics: _topicRows([
        for (final q in session.questions)
          (
            id: q.topic.id,
            name: q.topic.name,
            answered: q.isAnswered,
            correct: q.isCorrect == true,
            seconds: q.timeSpentSeconds,
          ),
      ]),
    );
  }

  AttemptDetailsModel _attemptDetails(ExamAttempt attempt, String label) {
    if (attempt.isInProgress) {
      throw const ApiException(
        statusCode: 404,
        message: 'The exam is still in progress.',
      );
    }
    final result = attempt.toResult();
    return AttemptDetailsModel(
      summary: AttemptSummaryModel(
        attemptId: attempt.id,
        type: AttemptType.examSimulation,
        completedAt: attempt.submittedAt ?? attempt.expiresAt,
        contentLabel: label.isNotEmpty
            ? label
            : _label({
                for (final q in attempt.questions) q.topicId: q.topicName,
              }),
        totalQuestions: result.totalQuestions,
        answered: result.answered,
        correct: result.correct,
        scorePercent: result.scorePercent,
        durationSeconds: result.durationTaken.inSeconds,
      ),
      unanswered: result.unanswered,
      wrong: result.incorrect,
      averageTimePerQuestionSeconds: result.totalQuestions == 0
          ? 0
          : result.durationTaken.inSeconds ~/ result.totalQuestions,
      topics: _topicRows([
        for (final q in attempt.questions)
          (
            id: q.topicId,
            name: q.topicName,
            answered: q.isAnswered,
            correct: q.isCorrect == true,
            seconds: q.timeSpentSeconds,
          ),
      ]),
    );
  }

  /// "First topic +N" from an attempt's own topic names — when the
  /// curriculum can't name its topics.
  static String _label(Map<String, String> topicNames) {
    final names = topicNames.values.toList();
    if (names.isEmpty) return '';
    return names.length == 1
        ? names.first
        : '${names.first} +${names.length - 1}';
  }

  /// Topic grouping on the client (contract §A4).
  static List<TopicPerformanceModel> _topicRows(
    List<({String id, String name, bool answered, bool correct, int seconds})>
    questions,
  ) {
    final rows =
        <
          String,
          List<
            ({String id, String name, bool answered, bool correct, int seconds})
          >
        >{};
    for (final q in questions) {
      (rows[q.id] ??= []).add(q);
    }
    return [
      for (final group in rows.values)
        () {
          final answered = group.where((q) => q.answered).length;
          final correct = group.where((q) => q.correct).length;
          final seconds = group.fold<int>(0, (sum, q) => sum + q.seconds);
          return TopicPerformanceModel(
            topicId: group.first.id,
            topicName: group.first.name,
            questionsAttempted: group.length,
            answered: answered,
            correct: correct,
            wrong: answered - correct,
            averageTimePerQuestionSeconds: answered == 0
                ? null
                : (seconds / answered).round(),
          );
        }(),
    ];
  }
}
