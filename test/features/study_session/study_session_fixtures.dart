import 'package:mobile/features/study_session/data/models/study_session_model.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/study_session.dart';

/// One question for [fakeSession]: [choices] maps choice id → text.
class FakeQuestion {
  const FakeQuestion({
    required this.id,
    required this.text,
    required this.choices,
    required this.correctChoiceId,
    this.selectedChoiceId,
    this.revealed,
    this.flagged = false,
    this.timeSpentSeconds = 0,
    this.explanation,
    this.topicId = 'topic-1',
    this.topicName = 'Flexible Budget',
  });

  final String id;
  final String text;
  final Map<String, String> choices;
  final String correctChoiceId;
  final String? selectedChoiceId;

  /// Defaults to the API's rule (answered in immediate mode, or completed).
  final bool? revealed;
  final bool flagged;
  final int timeSpentSeconds;
  final String? explanation;
  final String topicId;
  final String topicName;

  FakeQuestion answer(String choiceId, {int addSeconds = 0}) => FakeQuestion(
    id: id,
    text: text,
    choices: choices,
    correctChoiceId: correctChoiceId,
    selectedChoiceId: choiceId,
    revealed: revealed,
    flagged: flagged,
    timeSpentSeconds: timeSpentSeconds + addSeconds,
    explanation: explanation,
    topicId: topicId,
    topicName: topicName,
  );

  FakeQuestion flag(bool value) => FakeQuestion(
    id: id,
    text: text,
    choices: choices,
    correctChoiceId: correctChoiceId,
    selectedChoiceId: selectedChoiceId,
    revealed: revealed,
    flagged: value,
    timeSpentSeconds: timeSpentSeconds,
    explanation: explanation,
    topicId: topicId,
    topicName: topicName,
  );
}

const q1 = FakeQuestion(
  id: 'q1',
  text: 'What is 2 + 2?',
  choices: {'q1-a': '3', 'q1-b': '4'},
  correctChoiceId: 'q1-b',
  explanation: '2 + 2 = 4.',
);

const q2 = FakeQuestion(
  id: 'q2',
  text: 'What is 3 + 3?',
  choices: {'q2-a': '5', 'q2-b': '6'},
  correctChoiceId: 'q2-b',
);

/// A study session exactly as the API would return it, parsed by the app's
/// own parser — so fixtures can't drift from the real shape.
StudySession fakeSession({
  String id = 'sess-1',
  String status = 'IN_PROGRESS',
  FeedbackMode feedbackMode = FeedbackMode.immediate,
  List<FakeQuestion> questions = const [q1, q2],
}) => studySessionFromJson(
  fakeSessionJson(
    id: id,
    status: status,
    feedbackMode: feedbackMode,
    questions: questions,
  ),
);

Map<String, dynamic> fakeSessionJson({
  String id = 'sess-1',
  String status = 'IN_PROGRESS',
  FeedbackMode feedbackMode = FeedbackMode.immediate,
  List<FakeQuestion> questions = const [q1, q2],
}) {
  final completed = status == 'COMPLETED';
  bool revealed(FakeQuestion q) =>
      q.revealed ??
      (completed ||
          (feedbackMode == FeedbackMode.immediate &&
              q.selectedChoiceId != null));
  bool? isCorrect(FakeQuestion q) => revealed(q) && q.selectedChoiceId != null
      ? q.selectedChoiceId == q.correctChoiceId
      : null;
  final answered = questions.where((q) => q.selectedChoiceId != null);
  return {
    'id': id,
    'userId': 'user-1',
    'status': status,
    'feedbackMode': feedbackModeToWire(feedbackMode),
    'topicIds': [questions.isEmpty ? 'topic-1' : questions.first.topicId],
    'difficulty': null,
    'requestedCount': questions.length,
    'createdAt': '2026-10-08T10:00:00.000Z',
    'updatedAt': '2026-10-08T10:00:00.000Z',
    'completedAt': completed ? '2026-10-08T10:10:00.000Z' : null,
    'progress': {
      'total': questions.length,
      'answered': answered.length,
      'flagged': questions.where((q) => q.flagged).length,
      'correct': answered.where((q) => isCorrect(q) == true).length,
    },
    'questions': [
      for (final (index, q) in questions.indexed)
        {
          'id': 'sq-$index',
          'questionId': q.id,
          'order': index,
          'isFlagged': q.flagged,
          'answeredAt': q.selectedChoiceId == null
              ? null
              : '2026-10-08T10:0$index:00.000Z',
          'timeSpentSeconds': q.timeSpentSeconds,
          'selectedChoiceId': q.selectedChoiceId,
          'isCorrect': isCorrect(q),
          'question': {
            'id': q.id,
            'text': q.text,
            'topic': {
              'id': q.topicId,
              'name': q.topicName,
              'description': null,
            },
            'code': index + 1,
            'losCode': null,
            'difficulty': 'MEDIUM',
            'explanation': revealed(q) ? q.explanation : null,
          },
          'choices': [
            for (final entry in q.choices.entries)
              {
                'id': entry.key,
                'text': entry.value,
                if (revealed(q)) 'isCorrect': entry.key == q.correctChoiceId,
              },
          ],
        },
    ],
  };
}

const testSessionConfig = SessionConfig(
  topicId: 'topic-1',
  topicName: 'Flexible Budget',
  questionCount: 10,
  feedbackMode: FeedbackMode.immediate,
);

/// The "Variance Analysis" session the connected-loop tests use: 10
/// questions; once completed, 9 answered, 3 correct, 45 s in total — the
/// 30% attempt in test/features/performance/local_attempt_test_data.dart.
StudySession varianceSession({
  String status = 'IN_PROGRESS',
  int answeredCount = 0,
}) {
  final completed = status == 'COMPLETED';
  return fakeSession(
    id: 'mock-session-0',
    status: status,
    feedbackMode: FeedbackMode.immediate,
    questions: [
      for (var i = 0; i < 10; i++)
        () {
          final question = FakeQuestion(
            id: 'vq$i',
            text: i == 0 ? 'What is a variance?' : 'Variance question $i',
            choices: {
              'vq$i-a': i == 0 ? 'A difference' : 'Right',
              'vq$i-b': 'Wrong',
            },
            correctChoiceId: 'vq$i-a',
            topicId: 'topic-variance-analysis',
            topicName: 'Variance Analysis',
          );
          final answered = completed ? i < 9 : i < answeredCount;
          if (!answered) return question;
          return question.answer(i < 3 ? 'vq$i-a' : 'vq$i-b', addSeconds: 5);
        }(),
    ],
  );
}
