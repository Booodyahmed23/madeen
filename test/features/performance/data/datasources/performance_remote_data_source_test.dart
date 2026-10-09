import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/performance/data/datasources/performance_remote_data_source.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';

import '../../../exam_simulation/exam_fixtures.dart';
import '../../../study_session/study_session_fixtures.dart';

/// Answers by path; unknown paths are 404s.
class _Adapter implements HttpClientAdapter {
  _Adapter(this.routes);

  final Map<String, Object> routes;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final body = routes[options.path];
    return ResponseBody.fromString(
      jsonEncode(body ?? {'statusCode': 404, 'message': 'Not found'}),
      body == null ? 404 : 200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _historyRow({
  required String id,
  String type = 'STUDY',
  String? finalizedAt = '2026-10-08T21:02:17.289Z',
  int? correct = 14,
}) => {
  'type': type,
  'id': id,
  'status': finalizedAt == null ? 'IN_PROGRESS' : 'COMPLETED',
  'createdAt': '2026-10-08T21:00:00.000Z',
  'finalizedAt': finalizedAt,
  'requestedCount': 20,
  'topicIds': ['t1', 't2', 't3'],
  'difficulty': null,
  'answeredCount': 18,
  'correctCount': correct,
  'totalTimeSeconds': 640,
};

void main() {
  late _Adapter adapter;
  late PerformanceRemoteDataSource source;

  void serve(Map<String, Object> routes) {
    adapter = _Adapter(routes);
    source = PerformanceRemoteDataSource(
      ApiClient(Dio()..httpClientAdapter = adapter),
      labelTopics: (ids) async => 'Budgeting +${ids.length - 1}',
    );
  }

  test('overview maps the contract fields, nulls to zero', () async {
    serve({
      '/results/overview': {
        'totalAttempts': 12,
        'inProgressAttempts': 1,
        'questionsPracticed': 240,
        'totalAnswered': 220,
        'totalCorrect': 168,
        'accuracy': 76.4,
        'scorePercent': null,
        'totalTimeSeconds': 9300,
        'avgTimeSeconds': 42.4,
      },
    });

    final overview = (await source.getOverview(
      const PerformanceFilter(attemptType: AttemptTypeFilter.examSimulation),
    )).toEntity();

    expect(adapter.requests.single.queryParameters, {'type': 'EXAM'});
    expect(overview.questionsPracticed, 240);
    expect(overview.overallScorePercent, 0);
    expect(overview.totalTime, const Duration(seconds: 9300));
    expect(overview.averageTimePerQuestion, const Duration(seconds: 42));
  });

  test('topic performance: total is the answered count', () async {
    serve({
      '/results/performance/topics': [
        {
          'id': 't1',
          'name': 'Budgeting',
          'correct': 7,
          'total': 11,
          'accuracy': 63.6,
          'avgTimeSeconds': null,
        },
      ],
    });

    final topic = (await source.getTopicPerformance(const PerformanceFilter()))
        .single
        .toEntity();

    expect(adapter.requests.single.queryParameters, isEmpty);
    expect(topic.topicName, 'Budgeting');
    expect(topic.answered, 11);
    expect(topic.wrong, 4);
    expect(topic.averageTimePerQuestion, isNull);
  });

  test('history pages by page/limit, labels topics and skips unfinished '
      'rows', () async {
    serve({
      '/results/history': {
        'data': [
          _historyRow(id: 'a'),
          _historyRow(id: 'b', finalizedAt: null),
          _historyRow(id: 'c', type: 'EXAM', correct: null),
        ],
        'meta': {'page': 2, 'limit': 20, 'total': 45, 'totalPages': 3},
      },
    });

    final page = (await source.getAttempts(
      const PerformanceFilter(attemptType: AttemptTypeFilter.studySession),
      limit: 20,
      offset: 20,
    )).toEntity();

    expect(adapter.requests.single.queryParameters, {
      'page': 2,
      'limit': 20,
      'type': 'STUDY',
    });
    expect(page.items.map((i) => i.attemptId), ['a', 'c']);
    expect(page.hasMore, isTrue);
    final first = page.items.first;
    expect(first.contentLabel, 'Budgeting +2');
    expect(first.totalQuestions, 20);
    expect(first.answered, 18);
    expect(first.scorePercent, 70);
    expect(first.duration, const Duration(seconds: 640));
    expect(page.items.last.type, AttemptType.examSimulation);
    expect(page.items.last.correct, 0);
  });

  test('details of a study session come from the session', () async {
    serve({
      '/study/sessions/sess-1': fakeSessionJson(
        status: 'COMPLETED',
        questions: [q1.answer('q1-b', addSeconds: 30), q2],
      ),
    });

    final details = (await source.getAttemptDetails('sess-1')).toEntity();

    expect(details.summary.type, AttemptType.studySession);
    expect(details.summary.correct, 1);
    expect(details.unanswered, 1);
    // Labelled like the same attempt in history.
    expect(details.summary.contentLabel, 'Budgeting +0');
    expect(details.topics.single.answered, 1);
  });

  test('an id that is not a study session is looked up as an exam', () async {
    serve({
      '/exams/attempts/attempt-1': fakeAttemptJson(
        status: 'SUBMITTED',
        questions: [eq1.answer('eq1-a'), eq2],
      ),
    });

    final details = (await source.getAttemptDetails('attempt-1')).toEntity();

    expect(adapter.requests.map((r) => r.path), [
      '/study/sessions/attempt-1',
      '/exams/attempts/attempt-1',
    ]);
    expect(details.summary.type, AttemptType.examSimulation);
    expect(details.summary.contentLabel, 'Budgeting +1');
    expect(details.topics, hasLength(2));
  });

  test('parts and the 7-day trend use their endpoints', () async {
    serve({
      '/results/performance/parts': [
        {
          'id': 'p1',
          'name': 'Part 1',
          'correct': 10,
          'total': 15,
          'accuracy': 66.7,
          'avgTimeSeconds': 6,
        },
      ],
      '/results/performance/trend': [
        {'date': '2026-10-08', 'correct': 2, 'total': 4, 'accuracy': 50},
        {'date': '2026-10-09', 'correct': 0, 'total': 0, 'accuracy': null},
      ],
    });

    final parts = await source.getPartPerformance(
      const PerformanceFilter(attemptType: AttemptTypeFilter.studySession),
    );
    final trend = await source.getTrend(days: 7);

    expect(parts.single.toEntity().wrong, 5);
    expect(adapter.requests.first.queryParameters, {'type': 'STUDY'});
    final trendQuery = adapter.requests.last.queryParameters;
    expect(trendQuery['days'], 7);
    expect(
      trendQuery['tzOffsetMinutes'],
      DateTime.now().timeZoneOffset.inMinutes,
    );
    expect(trend.first.accuracyPercent, 50);
    expect(trend.last.accuracyPercent, isNull);
    expect(trend.first.date, DateTime(2026, 10, 8));
  });
}
