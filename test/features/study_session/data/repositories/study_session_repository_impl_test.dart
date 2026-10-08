import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/study_session/data/datasources/study_session_data_source.dart';
import 'package:mobile/features/study_session/data/repositories/study_session_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

import '../../study_session_fixtures.dart';

class MockStudySessionDataSource extends Mock
    implements StudySessionDataSource {}

void main() {
  late MockStudySessionDataSource dataSource;
  late StudySessionRepositoryImpl repository;

  setUpAll(() => registerFallbackValue(testSessionConfig));

  setUp(() {
    dataSource = MockStudySessionDataSource();
    repository = StudySessionRepositoryImpl(dataSource);
  });

  test('parses the session the data source returns', () async {
    when(() => dataSource.startSession(any()))
        .thenAnswer((_) async => fakeSessionJson());

    final result = await repository.startSession(testSessionConfig);

    expect((result as Success).value.id, 'sess-1');
  });

  test('a 403 on start becomes NoAccessFailure', () async {
    when(() => dataSource.startSession(any())).thenThrow(
      const ApiException(
        statusCode: 403,
        message: 'An active subscription is required',
      ),
    );

    final result = await repository.startSession(testSessionConfig);

    expect((result as Failure).failure, isA<NoAccessFailure>());
  });

  test('time spent is clamped to the API range', () async {
    when(
      () => dataSource.answerQuestion(
        sessionId: any(named: 'sessionId'),
        questionId: any(named: 'questionId'),
        choiceId: any(named: 'choiceId'),
        timeSpentSeconds: any(named: 'timeSpentSeconds'),
      ),
    ).thenAnswer((_) async => fakeSessionJson());

    await repository.answerQuestion(
      sessionId: 's',
      questionId: 'q',
      choiceId: 'c',
      timeSpentSeconds: 99999,
    );

    verify(
      () => dataSource.answerQuestion(
        sessionId: 's',
        questionId: 'q',
        choiceId: 'c',
        timeSpentSeconds: 3600,
      ),
    ).called(1);
  });

  group('completeSession', () {
    test('"already completed" fetches the completed session instead', () async {
      when(() => dataSource.completeSession('sess-1')).thenThrow(
        const ApiException(
          statusCode: 400,
          message: 'Session is already completed',
        ),
      );
      when(() => dataSource.getSession('sess-1'))
          .thenAnswer((_) async => fakeSessionJson(status: 'COMPLETED'));

      final result = await repository.completeSession('sess-1');

      expect((result as Success).value.isCompleted, isTrue);
    });

    test('a network failure stays a failure', () async {
      when(() => dataSource.completeSession('sess-1'))
          .thenThrow(const ApiException(statusCode: 0, message: 'offline'));

      final result = await repository.completeSession('sess-1');

      expect((result as Failure).failure, isA<NetworkFailure>());
      verifyNever(() => dataSource.getSession(any()));
    });
  });

  test('lists summaries from { data, meta }', () async {
    final row = fakeSessionJson()..remove('questions');
    when(() => dataSource.listSessions(page: 1, limit: 20)).thenAnswer(
      (_) async => {
        'data': [row],
        'meta': {'page': 1, 'limit': 20, 'total': 1, 'totalPages': 1},
      },
    );

    final result = await repository.listSessions();

    final page = (result as Success).value;
    expect(page.items.single.id, 'sess-1');
    expect(page.hasMore, isFalse);
  });

  test('an unexpected shape becomes UnknownFailure', () async {
    when(() => dataSource.getSession(any()))
        .thenAnswer((_) async => {'nonsense': true});

    final result = await repository.getSession('x');

    expect((result as Failure).failure, isA<UnknownFailure>());
  });
}
