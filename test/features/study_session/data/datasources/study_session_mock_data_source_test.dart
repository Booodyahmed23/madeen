import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/study_session/data/datasources/study_session_mock_data_source.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';

void main() {
  late StudySessionMockDataSource dataSource;

  setUp(() => dataSource = StudySessionMockDataSource());

  const config = SessionConfig(
    topicId: 'topic-flexible-budget',
    topicName: 'Flexible Budget',
    questionCount: 10,
    order: QuestionOrder.original,
    feedbackMode: FeedbackMode.immediate,
  );

  test(
    'startSession returns exactly questionCount questions, each with 4 choices',
    () async {
      final bundle = await dataSource.startSession(config);

      expect(bundle.questions, hasLength(10));
      for (final question in bundle.questions) {
        expect(question.choices, hasLength(4));
      }
    },
  );

  test('submitAnswer, submitSession, and getReview all agree on which choice is correct', () async {
    final bundle = await dataSource.startSession(config);
    final firstQuestion = bundle.questions.first;

    // Try every choice for the first question via submitAnswer and record
    // which one submitAnswer considers correct.
    String? correctPerFeedback;
    for (final choice in firstQuestion.choices) {
      final feedback = await dataSource.submitAnswer(
        sessionId: bundle.sessionId,
        questionId: firstQuestion.id,
        selectedChoiceId: choice.id,
      );
      expect(feedback.correctChoiceId, isNotEmpty);
      correctPerFeedback = feedback.correctChoiceId;
      expect(feedback.isCorrect, choice.id == feedback.correctChoiceId);
    }

    // Now submit the whole session answering every question with its
    // feedback-confirmed correct choice — score must be 100%.
    final answers = <String, String?>{};
    for (final question in bundle.questions) {
      final feedback = await dataSource.submitAnswer(
        sessionId: bundle.sessionId,
        questionId: question.id,
        selectedChoiceId: question.choices.first.id,
      );
      answers[question.id] = feedback.correctChoiceId;
    }

    final result = await dataSource.submitSession(
      sessionId: bundle.sessionId,
      answers: answers,
      totalTime: const Duration(minutes: 5),
    );

    expect(result.correct, result.totalQuestions);
    expect(result.scorePercent, 100.0);

    final review = await dataSource.getReview(bundle.sessionId);
    expect(review, hasLength(bundle.questions.length));
    for (final item in review) {
      expect(item.isCorrect, isTrue);
      expect(item.selectedChoiceId, item.correctChoiceId);
    }
    expect(
      review
          .firstWhere((r) => r.questionId == firstQuestion.id)
          .correctChoiceId,
      correctPerFeedback,
    );
  });

  test('submitSession correctly tallies unanswered questions', () async {
    final bundle = await dataSource.startSession(config);
    final answers = <String, String?>{
      for (final q in bundle.questions) q.id: null,
    };

    final result = await dataSource.submitSession(
      sessionId: bundle.sessionId,
      answers: answers,
      totalTime: const Duration(minutes: 1),
    );

    expect(result.answered, 0);
    expect(result.unanswered, bundle.questions.length);
    expect(result.correct, 0);
    expect(result.scorePercent, 0.0);
  });

  test('getReview on an unknown session returns an empty list rather than throwing', () async {
    final review = await dataSource.getReview('unknown-session');
    expect(review, isEmpty);
  });

  test('random order is deterministic for the same topicId', () async {
    final randomConfig = SessionConfig(
      topicId: config.topicId,
      topicName: config.topicName,
      questionCount: config.questionCount,
      order: QuestionOrder.random,
      feedbackMode: config.feedbackMode,
    );

    final first = await StudySessionMockDataSource().startSession(randomConfig);
    final second = await StudySessionMockDataSource().startSession(
      randomConfig,
    );

    expect(
      first.questions.map((q) => q.text),
      second.questions.map((q) => q.text),
    );
  });
}
