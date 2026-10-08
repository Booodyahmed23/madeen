import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/study_session/data/datasources/study_session_mock_data_source.dart';
import 'package:mobile/features/study_session/data/models/study_session_model.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/study_session.dart';

import '../../study_session_fixtures.dart';

void main() {
  late StudySessionMockDataSource source;

  setUp(() => source = StudySessionMockDataSource(delay: Duration.zero));

  Future<StudySession> start(FeedbackMode mode) async => studySessionFromJson(
    await source.startSession(
      SessionConfig(
        topicId: 'topic-1',
        topicName: 'Budgeting',
        questionCount: 3,
        feedbackMode: mode,
      ),
    ),
  );

  test(
    'a new session has the requested number of unrevealed questions',
    () async {
      final session = await start(FeedbackMode.immediate);

      expect(session.questions, hasLength(3));
      expect(session.status, StudySessionStatus.inProgress);
      expect(session.questions.any((q) => q.isRevealed), isFalse);
    },
  );

  test('immediate mode reveals an answer at once', () async {
    final session = await start(FeedbackMode.immediate);
    final question = session.questions.first;

    final answered = studySessionFromJson(
      await source.answerQuestion(
        sessionId: session.id,
        questionId: question.questionId,
        choiceId: question.choices.first.id,
        timeSpentSeconds: 5,
      ),
    );

    expect(answered.questions.first.isRevealed, isTrue);
    expect(answered.questions.first.timeSpentSeconds, 5);
    expect(answered.progress.answered, 1);
  });

  test('deferred mode reveals everything only on completion', () async {
    final session = await start(FeedbackMode.atEnd);
    final question = session.questions.first;
    final answered = studySessionFromJson(
      await source.answerQuestion(
        sessionId: session.id,
        questionId: question.questionId,
        choiceId: question.choices.first.id,
      ),
    );
    expect(answered.questions.first.isRevealed, isFalse);

    final completed = studySessionFromJson(
      await source.completeSession(session.id),
    );
    expect(completed.isCompleted, isTrue);
    expect(completed.questions.every((q) => q.isRevealed), isTrue);
  });

  test('answering while paused, or completing twice, is a 400', () async {
    final session = await start(FeedbackMode.immediate);
    final question = session.questions.first;
    await source.pauseSession(session.id);

    await expectLater(
      source.answerQuestion(
        sessionId: session.id,
        questionId: question.questionId,
        choiceId: question.choices.first.id,
      ),
      throwsA(isA<ApiException>()),
    );

    await source.resumeSession(session.id);
    await source.completeSession(session.id);
    await expectLater(
      source.completeSession(session.id),
      throwsA(
        isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
      ),
    );
  });

  test('lists sessions newest first, without questions', () async {
    await start(FeedbackMode.immediate);
    final second = await start(FeedbackMode.atEnd);

    final page = await source.listSessions(page: 1, limit: 20);

    final rows = page['data'] as List;
    expect((rows.first as Map)['id'], second.id);
    expect((rows.first as Map).containsKey('questions'), isFalse);
    expect(page['meta'], containsPair('total', 2));
  });

  test('the mock produces JSON the shared fixtures agree with', () {
    expect(fakeSession().questions, hasLength(2));
  });
}
