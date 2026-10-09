import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/study_session/data/datasources/study_session_remote_data_source.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';

import '../../study_session_fixtures.dart';

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
      jsonEncode(fakeSessionJson()),
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
  late StudySessionRemoteDataSource source;

  setUp(() {
    adapter = _Adapter();
    source = StudySessionRemoteDataSource(
      ApiClient(Dio()..httpClientAdapter = adapter),
    );
  });

  RequestOptions last() => adapter.requests.last;

  test('create sends only the documented fields', () async {
    await source.startSession(
      const SessionConfig(
        topicId: 'topic-1',
        topicName: 'Budgeting',
        questionCount: 20,
        feedbackMode: FeedbackMode.atEnd,
      ),
    );

    expect(last().method, 'POST');
    expect(last().path, '/study/sessions');
    expect(last().data, {
      'topicIds': ['topic-1'],
      'questionCount': 20,
      'feedbackMode': 'DEFERRED',
    });
  });

  test('"all my topics" omits topicIds; several topics and difficulty are '
      'sent', () async {
    await source.startSession(
      const SessionConfig(
        topicName: 'All my topics',
        questionCount: 15,
        feedbackMode: FeedbackMode.immediate,
      ),
    );
    expect(last().data, {'questionCount': 15, 'feedbackMode': 'IMMEDIATE'});

    await source.startSession(
      const SessionConfig(
        topicIds: ['t1', 't2'],
        topicName: 'Budgeting',
        questionCount: 100,
        feedbackMode: FeedbackMode.atEnd,
        difficulty: QuestionDifficulty.hard,
      ),
    );
    expect(last().data, {
      'topicIds': ['t1', 't2'],
      'questionCount': 100,
      'feedbackMode': 'DEFERRED',
      'difficulty': 'HARD',
    });
  });

  test('answer PATCHes the bank question id with choice and time', () async {
    await source.answerQuestion(
      sessionId: 's1',
      questionId: 'bank-1',
      choiceId: 'c1',
      timeSpentSeconds: 7,
    );

    expect(last().method, 'PATCH');
    expect(last().path, '/study/sessions/s1/questions/bank-1/answer');
    expect(last().data, {'choiceId': 'c1', 'timeSpentSeconds': 7});
  });

  test('flag, pause, resume, complete, get and list use their paths', () async {
    await source.flagQuestion(sessionId: 's1', questionId: 'q', flagged: true);
    expect(last().path, '/study/sessions/s1/questions/q/flag');
    expect(last().data, {'flagged': true});

    await source.pauseSession('s1');
    expect((last().method, last().path), ('PATCH', '/study/sessions/s1/pause'));

    await source.resumeSession('s1');
    expect(
      (last().method, last().path),
      ('PATCH', '/study/sessions/s1/resume'),
    );

    await source.completeSession('s1');
    expect(
      (last().method, last().path),
      ('POST', '/study/sessions/s1/complete'),
    );
    expect(last().data, isNull);

    await source.getSession('s1');
    expect((last().method, last().path), ('GET', '/study/sessions/s1'));

    await source.listSessions(page: 2, limit: 20);
    expect(last().path, '/study/sessions');
    expect(last().queryParameters, {'page': 2, 'limit': 20});
  });
}
