/// `IMMEDIATE` (each answer is revealed once given) or `DEFERRED` (revealed
/// when the session is completed).
enum FeedbackMode { immediate, atEnd }

/// Question-count presets the Setup screen offers. The API accepts any
/// count from 1 to 100.
const List<int> kQuestionCountOptions = [10, 20, 30, 40, 50];

/// What the student configured before starting. `topicId`/`topicName` come
/// from Curriculum navigation (the student arrives here from a specific
/// Topic — see AppRoutes.curriculumTopicDetail). There is no question-order
/// option: the server always shuffles.
class SessionConfig {
  const SessionConfig({
    required this.topicId,
    required this.topicName,
    required this.questionCount,
    required this.feedbackMode,
  });

  final String topicId;
  final String topicName;
  final int questionCount;
  final FeedbackMode feedbackMode;
}
