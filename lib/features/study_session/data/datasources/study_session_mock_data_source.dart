import 'dart:math';

import '../../domain/entities/question_type.dart';
import '../../domain/entities/session_config.dart';
import '../models/answer_choice_model.dart';
import '../models/question_feedback_model.dart';
import '../models/question_model.dart';
import '../models/question_review_item_model.dart';
import '../models/session_result_model.dart';
import '../models/study_session_bundle_model.dart';
import 'study_session_data_source.dart';

class _MockSession {
  _MockSession(this.topicName, this.questions, this.correctChoiceByQuestion);

  final String topicName;
  final List<QuestionModel> questions;
  final Map<String, String> correctChoiceByQuestion;
  Map<String, String?> lastAnswers = const {};
}

/// Local sample questions — used only because the real Study Session /
/// Question Bank API does not exist yet (see
/// STUDY_SESSION_API_REQUIREMENTS.md). Generates a plausible multiple-choice
/// set for *any* topic reached through Curriculum, not just one hardcoded
/// example, so the whole browse → practice flow is demoable end to end.
/// This is a UI-development aid, **not** production content — see
/// SampleDataBanner, shown on every screen this data source feeds.
class StudySessionMockDataSource implements StudySessionDataSource {
  static const _artificialDelay = Duration(milliseconds: 400);
  static const _choiceLetters = ['A', 'B', 'C', 'D'];

  final _sessions = <String, _MockSession>{};
  var _sessionCounter = 0;

  @override
  Future<StudySessionBundleModel> startSession(SessionConfig config) async {
    await Future<void>.delayed(_artificialDelay);

    final questions = List.generate(config.questionCount, (index) {
      final questionId = 'mock-q-${config.topicId}-$index';
      final correctIndex = index % _choiceLetters.length;
      final choices = List.generate(
        _choiceLetters.length,
        (choiceIndex) => AnswerChoiceModel(
          id: '$questionId-choice-$choiceIndex',
          text:
              '${_choiceLetters[choiceIndex]}) Sample answer ${choiceIndex + 1} for question ${index + 1}',
          order: choiceIndex,
        ),
      );
      return (
        model: QuestionModel(
          id: questionId,
          text: 'Sample question ${index + 1} about "${config.topicName}".',
          type: QuestionType.multipleChoiceSingle,
          choices: choices,
          difficulty: index % 3 == 0 ? 'Medium' : null,
        ),
        correctChoiceId: choices[correctIndex].id,
      );
    });

    if (config.order == QuestionOrder.random) {
      questions.shuffle(Random(config.topicId.hashCode));
    }

    final sessionId = 'mock-session-${_sessionCounter++}';
    _sessions[sessionId] = _MockSession(
      config.topicName,
      [for (final q in questions) q.model],
      {for (final q in questions) q.model.id: q.correctChoiceId},
    );

    return StudySessionBundleModel(
      sessionId: sessionId,
      questions: [for (final q in questions) q.model],
    );
  }

  @override
  Future<QuestionFeedbackModel> submitAnswer({
    required String sessionId,
    required String questionId,
    String? selectedChoiceId,
  }) async {
    await Future<void>.delayed(_artificialDelay);
    final session = _sessions[sessionId];
    final correctChoiceId = session?.correctChoiceByQuestion[questionId] ?? '';

    return QuestionFeedbackModel(
      questionId: questionId,
      isCorrect:
          selectedChoiceId != null && selectedChoiceId == correctChoiceId,
      correctChoiceId: correctChoiceId,
      explanation:
          'This is sample explanation text for a mock question — replace once the '
          'real Question Bank API is connected.',
    );
  }

  @override
  Future<SessionResultModel> submitSession({
    required String sessionId,
    required Map<String, String?> answers,
    required Duration totalTime,
  }) async {
    await Future<void>.delayed(_artificialDelay);
    final session = _sessions[sessionId];
    if (session == null) {
      throw StateError('Unknown mock session: $sessionId');
    }
    session.lastAnswers = answers;

    final total = session.questions.length;
    var correct = 0;
    var answered = 0;
    for (final question in session.questions) {
      final selected = answers[question.id];
      if (selected != null) {
        answered++;
        if (selected == session.correctChoiceByQuestion[question.id]) correct++;
      }
    }
    final unanswered = total - answered;
    final incorrect = answered - correct;

    return SessionResultModel(
      sessionId: sessionId,
      totalQuestions: total,
      answered: answered,
      unanswered: unanswered,
      correct: correct,
      incorrect: incorrect,
      scorePercent: total == 0 ? 0 : (correct / total) * 100,
      totalTimeSeconds: totalTime.inSeconds,
      averageTimePerQuestionSeconds: total == 0
          ? 0
          : totalTime.inSeconds / total,
    );
  }

  @override
  Future<List<QuestionReviewItemModel>> getReview(String sessionId) async {
    await Future<void>.delayed(_artificialDelay);
    final session = _sessions[sessionId];
    if (session == null) return const [];

    return [
      for (final question in session.questions)
        QuestionReviewItemModel(
          questionId: question.id,
          questionText: question.text,
          choices: question.choices,
          correctChoiceId: session.correctChoiceByQuestion[question.id]!,
          selectedChoiceId: session.lastAnswers[question.id],
          isCorrect:
              session.lastAnswers[question.id] != null &&
              session.lastAnswers[question.id] ==
                  session.correctChoiceByQuestion[question.id],
          explanation:
              'This is sample explanation text for a mock question — replace once the '
              'real Question Bank API is connected.',
        ),
    ];
  }
}
