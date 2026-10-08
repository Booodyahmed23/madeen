import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/exam_simulation/data/datasources/exam_remote_data_source.dart';

import '../../exam_fixtures.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(
      jsonEncode(fakeAttemptJson()),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late _Adapter adapter;
  late ExamRemoteDataSource source;

  setUp(() {
    adapter = _Adapter();
    source = ExamRemoteDataSource(
      ApiClient(Dio()..httpClientAdapter = adapter),
    );
  });

  RequestOptions last() => adapter.requests.last;

  test('create sends topic ids, count and whole minutes only', () async {
    await source.startExam(testExamConfig);

    expect((last().method, last().path), ('POST', '/exams/attempts'));
    expect(last().data, {
      'topicIds': ['topic-1', 'topic-2'],
      'questionCount': 10,
      'durationMinutes': 15,
    });
  });

  test('answer, flag and submit use their paths and bodies', () async {
    await source.answerQuestion(
      attemptId: 'a1',
      questionId: 'bank-1',
      choiceId: 'c1',
      timeSpentSeconds: 4,
    );
    expect(last().method, 'PATCH');
    expect(last().path, '/exams/attempts/a1/questions/bank-1/answer');
    expect(last().data, {'choiceId': 'c1', 'timeSpentSeconds': 4});

    await source.flagQuestion(attemptId: 'a1', questionId: 'q', flagged: true);
    expect(last().path, '/exams/attempts/a1/questions/q/flag');
    expect(last().data, {'flagged': true});

    await source.submitExam('a1');
    expect((last().method, last().path), ('POST', '/exams/attempts/a1/submit'));
    expect(last().data, isNull);

    await source.getAttempt('a1');
    expect((last().method, last().path), ('GET', '/exams/attempts/a1'));

    await source.listAttempts(page: 1, limit: 20);
    expect(last().queryParameters, {'page': 1, 'limit': 20});
  });
}
