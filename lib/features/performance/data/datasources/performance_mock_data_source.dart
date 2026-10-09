import '../../domain/entities/attempt_type.dart';
import '../../domain/entities/performance_filter.dart';
import '../../domain/entities/trend_day.dart';
import '../models/attempt_details_model.dart';
import '../models/attempt_history_page_model.dart';
import '../models/attempt_summary_model.dart';
import '../models/local_attempt_record.dart';
import '../models/performance_overview_model.dart';
import '../models/topic_performance_model.dart';
import 'performance_data_source.dart';

/// Local sample data, used while `PERFORMANCE_API_AVAILABLE` is off (the
/// real API is docs/MOBILE_API_CONTRACT.md §A5). This
/// is a UI-development aid, **not** production content: a small, hand-written,
/// internally-consistent fixture (see the class-level comment on each list
/// below for how the numbers were derived), selected automatically when
/// `AppConfig.isPerformanceApiAvailable` is `false` (the default) — see
/// performance_data_source.dart.
///
/// Every aggregate this class returns (overview totals, topic rows, paged
/// attempts) is *computed* from the single [_attempts] list below rather
/// than hand-duplicated — this is what "internally consistent" means in
/// practice: change a number in [_attempts] and every screen that derives
/// from it stays in agreement, exactly as a real backend's own aggregation
/// query would.
///
/// Since Phase 13 it also merges [localAttempts] — attempts the student
/// actually completed on this device (see LocalAttemptRecord) — ahead of
/// the fixtures: every aggregate below runs over `local + fixtures`, newest
/// first, exactly as it would over a backend's attempt table. The fixtures
/// themselves are untouched, so with no local attempts every number is
/// identical to before.
class PerformanceMockDataSource implements PerformanceDataSource {
  PerformanceMockDataSource({this.localAttempts = const []})
    : _allAttempts = localAttempts.isEmpty
          ? _attempts
          : ([
              for (final record in localAttempts) record.toSummaryModel(),
              ..._attempts,
            ]..sort((a, b) => b.completedAt.compareTo(a.completedAt)));

  static const _artificialDelay = Duration(milliseconds: 400);

  /// This user's recorded attempts (newest first), merged with the
  /// fixtures below.
  final List<LocalAttemptRecord> localAttempts;

  /// [localAttempts] + fixtures, newest first — what every query reads.
  final List<AttemptSummaryModel> _allAttempts;

  /// Six attempts, most-recent-first, mixing both attempt types and a
  /// spread of scores/accuracies/durations — including one attempt with
  /// unanswered questions (attempt 2) and one with a short exam-length
  /// duration edge (attempt 6) to exercise duration formatting at both
  /// ends. Dates are fixed (not `DateTime.now()`) so mock output — and
  /// every test built against it — is deterministic.
  static final List<AttemptSummaryModel> _attempts = [
    AttemptSummaryModel(
      attemptId: 'perf-attempt-1',
      type: AttemptType.studySession,
      completedAt: DateTime(2026, 9, 16, 9),
      contentLabel: 'Budgeting',
      totalQuestions: 20,
      answered: 20,
      correct: 18,
      scorePercent: 90.0,
      durationSeconds: 1200,
    ),
    AttemptSummaryModel(
      attemptId: 'perf-attempt-2',
      type: AttemptType.examSimulation,
      completedAt: DateTime(2026, 9, 15, 14),
      contentLabel: 'CMA Part 1',
      totalQuestions: 80,
      answered: 74,
      correct: 58,
      scorePercent: 72.5,
      durationSeconds: 12000,
    ),
    AttemptSummaryModel(
      attemptId: 'perf-attempt-3',
      type: AttemptType.studySession,
      completedAt: DateTime(2026, 9, 14, 10, 30),
      contentLabel: 'Financial Statements',
      totalQuestions: 20,
      answered: 20,
      correct: 15,
      scorePercent: 75.0,
      durationSeconds: 1600,
    ),
    AttemptSummaryModel(
      attemptId: 'perf-attempt-4',
      type: AttemptType.studySession,
      completedAt: DateTime(2026, 9, 12, 8, 15),
      contentLabel: 'Variance Analysis',
      totalQuestions: 20,
      answered: 20,
      correct: 11,
      scorePercent: 55.0,
      durationSeconds: 1800,
    ),
    AttemptSummaryModel(
      attemptId: 'perf-attempt-5',
      type: AttemptType.examSimulation,
      completedAt: DateTime(2026, 9, 10, 9),
      contentLabel: 'CMA Part 2',
      totalQuestions: 50,
      answered: 50,
      correct: 40,
      scorePercent: 80.0,
      durationSeconds: 7500,
    ),
    AttemptSummaryModel(
      attemptId: 'perf-attempt-6',
      type: AttemptType.studySession,
      completedAt: DateTime(2026, 9, 8, 19, 45),
      contentLabel: 'Cost Behavior',
      totalQuestions: 15,
      answered: 13,
      correct: 9,
      scorePercent: 60.0,
      durationSeconds: 900,
    ),
  ];

  /// One topic per Study Session attempt above (exam attempts contribute no
  /// topic rows — see [TopicPerformance]'s doc comment) — deliberately
  /// spans a strong topic (Budgeting, 90%), a needs-practice topic
  /// (Variance Analysis, 55%), and two neutral ones, so the Strong / Needs
  /// Practice filter has something real to filter.
  static final Map<String, TopicPerformanceModel> _topicByAttemptId = {
    'perf-attempt-1': const TopicPerformanceModel(
      topicId: 'topic-budgeting',
      topicName: 'Budgeting',
      questionsAttempted: 20,
      answered: 20,
      correct: 18,
      wrong: 2,
      averageTimePerQuestionSeconds: 60,
    ),
    'perf-attempt-3': const TopicPerformanceModel(
      topicId: 'topic-financial-statements',
      topicName: 'Financial Statements',
      questionsAttempted: 20,
      answered: 20,
      correct: 15,
      wrong: 5,
      averageTimePerQuestionSeconds: 80,
    ),
    'perf-attempt-4': const TopicPerformanceModel(
      topicId: 'topic-variance-analysis',
      topicName: 'Variance Analysis',
      questionsAttempted: 20,
      answered: 20,
      correct: 11,
      wrong: 9,
      averageTimePerQuestionSeconds: 90,
    ),
    'perf-attempt-6': const TopicPerformanceModel(
      topicId: 'topic-cost-behavior',
      topicName: 'Cost Behavior',
      questionsAttempted: 15,
      answered: 13,
      correct: 9,
      wrong: 4,
      averageTimePerQuestionSeconds: 69,
    ),
  };

  List<AttemptSummaryModel> _filtered(PerformanceFilter filter) {
    return switch (filter.attemptType) {
      AttemptTypeFilter.all => _allAttempts,
      AttemptTypeFilter.studySession =>
        _allAttempts.where((a) => a.type == AttemptType.studySession).toList(),
      AttemptTypeFilter.examSimulation =>
        _allAttempts
            .where((a) => a.type == AttemptType.examSimulation)
            .toList(),
    };
  }

  @override
  Future<PerformanceOverviewModel> getOverview(PerformanceFilter filter) async {
    await Future<void>.delayed(_artificialDelay);
    final attempts = _filtered(filter);

    final questionsPracticed = attempts.fold(
      0,
      (sum, a) => sum + a.totalQuestions,
    );
    final totalAnswered = attempts.fold(0, (sum, a) => sum + a.answered);
    final totalCorrect = attempts.fold(0, (sum, a) => sum + a.correct);
    final totalTimeSeconds = attempts.fold(
      0,
      (sum, a) => sum + a.durationSeconds,
    );

    return PerformanceOverviewModel(
      totalAttempts: attempts.length,
      questionsPracticed: questionsPracticed,
      totalAnswered: totalAnswered,
      totalCorrect: totalCorrect,
      overallScorePercent: questionsPracticed == 0
          ? 0
          : (totalCorrect / questionsPracticed) * 100,
      totalTimeSeconds: totalTimeSeconds,
      averageTimePerQuestionSeconds: questionsPracticed == 0
          ? 0
          : totalTimeSeconds ~/ questionsPracticed,
    );
  }

  @override
  Future<List<TopicPerformanceModel>> getTopicPerformance(
    PerformanceFilter filter,
  ) async {
    await Future<void>.delayed(_artificialDelay);
    // Fixture topic rows all belong to Study Session attempts; a recorded
    // attempt contributes its own rows (a session's topic, or an exam's
    // post-submission per-topic breakdown) under its own type.
    final includeFixtures =
        filter.attemptType != AttemptTypeFilter.examSimulation;
    final localRows = [
      for (final record in localAttempts)
        if (_matches(filter, record.type)) ...record.toTopicModels(),
    ];
    if (localRows.isEmpty) {
      return includeFixtures
          ? _topicByAttemptId.values.toList(growable: false)
          : const [];
    }
    return _aggregateTopics([
      if (includeFixtures) ..._topicByAttemptId.values,
      ...localRows,
    ]);
  }

  static bool _matches(PerformanceFilter filter, AttemptType type) =>
      switch (filter.attemptType) {
        AttemptTypeFilter.all => true,
        AttemptTypeFilter.studySession => type == AttemptType.studySession,
        AttemptTypeFilter.examSimulation => type == AttemptType.examSimulation,
      };

  /// One row per topic id — a topic practiced in several attempts (local,
  /// fixture, or both) is summed, never listed twice. Average time per
  /// question is weighted by questions answered, so a long session counts
  /// for more than a short one. Fixture topics keep their original order;
  /// newly practiced topics follow, in first-seen order.
  static List<TopicPerformanceModel> _aggregateTopics(
    List<TopicPerformanceModel> rows,
  ) {
    final byId = <String, List<TopicPerformanceModel>>{};
    for (final row in rows) {
      (byId[row.topicId] ??= []).add(row);
    }
    return [
      for (final group in byId.values)
        if (group.length == 1) group.single else _combine(group),
    ];
  }

  static TopicPerformanceModel _combine(List<TopicPerformanceModel> group) {
    final answered = group.fold(0, (sum, t) => sum + t.answered);
    final timed = group.where((t) => t.averageTimePerQuestionSeconds != null);
    final timedAnswered = timed.fold(0, (sum, t) => sum + t.answered);
    final weightedSeconds = timed.fold(
      0,
      (sum, t) => sum + t.averageTimePerQuestionSeconds! * t.answered,
    );
    return TopicPerformanceModel(
      topicId: group.first.topicId,
      topicName: group.first.topicName,
      questionsAttempted: group.fold(0, (sum, t) => sum + t.questionsAttempted),
      answered: answered,
      correct: group.fold(0, (sum, t) => sum + t.correct),
      wrong: group.fold(0, (sum, t) => sum + t.wrong),
      averageTimePerQuestionSeconds: timedAnswered == 0
          ? null
          : (weightedSeconds / timedAnswered).round(),
    );
  }

  @override
  Future<AttemptHistoryPageModel> getAttempts(
    PerformanceFilter filter, {
    required int limit,
    required int offset,
  }) async {
    await Future<void>.delayed(_artificialDelay);
    final filtered = _filtered(filter);
    final page = offset >= filtered.length
        ? const <AttemptSummaryModel>[]
        : filtered.sublist(offset, (offset + limit).clamp(0, filtered.length));
    return AttemptHistoryPageModel(
      items: page,
      hasMore: offset + page.length < filtered.length,
    );
  }

  @override
  Future<AttemptDetailsModel> getAttemptDetails(String attemptId) async {
    await Future<void>.delayed(_artificialDelay);
    for (final record in localAttempts) {
      if (record.attemptId == attemptId) return record.toDetailsModel();
    }
    final attempt = _attempts.firstWhere(
      (a) => a.attemptId == attemptId,
      orElse: () => throw StateError('Unknown mock attempt: $attemptId'),
    );
    final topic = _topicByAttemptId[attemptId];

    return AttemptDetailsModel(
      summary: attempt,
      unanswered: attempt.totalQuestions - attempt.answered,
      wrong: attempt.answered - attempt.correct,
      averageTimePerQuestionSeconds:
          attempt.durationSeconds ~/ attempt.totalQuestions,
      topics: topic == null ? const [] : [topic],
    );
  }

  @override
  Future<List<TopicPerformanceModel>> getPartPerformance(
    PerformanceFilter filter,
  ) async {
    await Future<void>.delayed(_artificialDelay);
    if (filter.attemptType == AttemptTypeFilter.examSimulation) {
      return const [];
    }
    return const [
      TopicPerformanceModel(
        topicId: 'cma-part-1',
        topicName: 'Part 1',
        questionsAttempted: 120,
        answered: 120,
        correct: 88,
        wrong: 32,
        averageTimePerQuestionSeconds: 52,
      ),
      TopicPerformanceModel(
        topicId: 'cma-part-2',
        topicName: 'Part 2',
        questionsAttempted: 40,
        answered: 40,
        correct: 22,
        wrong: 18,
        averageTimePerQuestionSeconds: 61,
      ),
    ];
  }

  /// A sample week ending today, with a rest day.
  @override
  Future<List<TrendDay>> getTrend({required int days}) async {
    await Future<void>.delayed(_artificialDelay);
    const sample = [
      (6, 10),
      (0, 0),
      (7, 10),
      (12, 15),
      (9, 12),
      (8, 10),
      (14, 16),
    ];
    final today = DateTime.now();
    return [
      for (var i = 0; i < days; i++)
        () {
          final (correct, total) =
              sample[(sample.length - days + i) % sample.length];
          return TrendDay(
            date: DateTime(today.year, today.month, today.day - (days - 1 - i)),
            correct: correct,
            total: total,
            accuracyPercent: total == 0 ? null : correct / total * 100,
          );
        }(),
    ];
  }
}
