enum QuestionOrder { original, random }

enum FeedbackMode { immediate, atEnd }

/// Question-count choices the Setup screen offers. Fixed to these values —
/// no free-form custom amount — because the (not-yet-existing) backend
/// contract doesn't define one; inventing an unsupported limit would be
/// exactly the "assume the API supports this" mistake
/// STUDY_SESSION_API_REQUIREMENTS.md is written to avoid.
const List<int> kQuestionCountOptions = [10, 20, 30, 40, 50];

/// What the student configured before starting. `topicId`/`topicName` come
/// from Curriculum navigation (the student always arrives here from a
/// specific Topic — see AppRoutes.curriculumTopicDetail) rather than being
/// re-selected on this screen, so Setup doesn't duplicate Curriculum's own
/// Program/Part/Unit/Sub-unit/Topic picker UI.
class SessionConfig {
  const SessionConfig({
    required this.topicId,
    required this.topicName,
    required this.questionCount,
    required this.order,
    required this.feedbackMode,
  });

  final String topicId;
  final String topicName;
  final int questionCount;
  final QuestionOrder order;
  final FeedbackMode feedbackMode;
}
