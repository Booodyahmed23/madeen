import '../../../../core/network/api_exception.dart';
import '../../domain/entities/session_config.dart';
import '../models/study_session_model.dart';
import 'study_session_data_source.dart';

class _MockQuestion {
  _MockQuestion({
    required this.questionId,
    required this.order,
    required this.text,
    required this.topicId,
    required this.topicName,
    required this.choices,
    required this.correctChoiceId,
  });

  final String questionId;
  final int order;
  final String text;
  final String topicId;
  final String topicName;
  final List<({String id, String text})> choices;
  final String correctChoiceId;
  bool isFlagged = false;
  DateTime? answeredAt;
  int timeSpentSeconds = 0;
  String? selectedChoiceId;
}

class _MockSession {
  _MockSession({
    required this.id,
    required this.feedbackMode,
    required this.topicId,
    required this.questions,
    required this.createdAt,
  });

  final String id;
  final FeedbackMode feedbackMode;
  final String topicId;
  final List<_MockQuestion> questions;
  final DateTime createdAt;
  String status = 'IN_PROGRESS';
  DateTime? completedAt;
}

/// Local sample questions, used while `STUDY_SESSION_API_AVAILABLE` is off.
/// An in-memory stand-in for the API: it keeps sessions, applies the same
/// rules (reveal, pause, complete) and returns the same JSON as the real
/// endpoints. A UI-development aid, **not** production content — see
/// SampleDataBanner, shown on every screen this data source feeds.
class StudySessionMockDataSource implements StudySessionDataSource {
  StudySessionMockDataSource({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;

  static const _choiceLetters = ['A', 'B', 'C', 'D'];

  final _sessions = <String, _MockSession>{};
  var _sessionCounter = 0;

  @override
  Future<Json> startSession(SessionConfig config) async {
    await Future<void>.delayed(delay);
    final questions = List.generate(config.questionCount, (index) {
      final questionId = 'mock-q-${config.topicId}-$index';
      final choices = [
        for (var c = 0; c < _choiceLetters.length; c++)
          (
            id: '$questionId-choice-$c',
            text:
                '${_choiceLetters[c]}) Sample answer ${c + 1} for question '
                '${index + 1}',
          ),
      ];
      return _MockQuestion(
        questionId: questionId,
        order: index,
        text: 'Sample question ${index + 1} about "${config.topicName}".',
        topicId: config.topicId,
        topicName: config.topicName,
        choices: choices,
        correctChoiceId: choices[index % choices.length].id,
      );
    });
    final session = _MockSession(
      id: 'mock-session-${_sessionCounter++}',
      feedbackMode: config.feedbackMode,
      topicId: config.topicId,
      questions: questions,
      createdAt: DateTime.now().toUtc(),
    );
    _sessions[session.id] = session;
    return _toJson(session);
  }

  @override
  Future<Json> getSession(String sessionId) async {
    await Future<void>.delayed(delay);
    return _toJson(_find(sessionId));
  }

  @override
  Future<Json> listSessions({required int page, required int limit}) async {
    final all = _sessions.values.toList().reversed.toList();
    final start = (page - 1) * limit;
    return {
      'data': [
        for (final session in all.skip(start).take(limit))
          _toJson(session)..remove('questions'),
      ],
      'meta': {
        'page': page,
        'limit': limit,
        'total': all.length,
        'totalPages': (all.length / limit).ceil(),
      },
    };
  }

  @override
  Future<Json> answerQuestion({
    required String sessionId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  }) async {
    await Future<void>.delayed(delay);
    final session = _find(sessionId);
    if (session.status != 'IN_PROGRESS') {
      throw const ApiException(
        statusCode: 400,
        message: 'Session is not in progress',
      );
    }
    final question = _question(session, questionId);
    question
      ..selectedChoiceId = choiceId
      ..answeredAt = DateTime.now().toUtc()
      ..timeSpentSeconds += timeSpentSeconds ?? 0;
    return _toJson(session);
  }

  @override
  Future<Json> flagQuestion({
    required String sessionId,
    required String questionId,
    required bool flagged,
  }) async {
    await Future<void>.delayed(delay);
    final session = _find(sessionId);
    _question(session, questionId).isFlagged = flagged;
    return _toJson(session);
  }

  @override
  Future<Json> pauseSession(String sessionId) async {
    final session = _find(sessionId);
    if (session.status == 'IN_PROGRESS') session.status = 'PAUSED';
    return _toJson(session);
  }

  @override
  Future<Json> resumeSession(String sessionId) async {
    final session = _find(sessionId);
    if (session.status == 'PAUSED') session.status = 'IN_PROGRESS';
    return _toJson(session);
  }

  @override
  Future<Json> completeSession(String sessionId) async {
    await Future<void>.delayed(delay);
    final session = _find(sessionId);
    if (session.status == 'COMPLETED') {
      throw const ApiException(
        statusCode: 400,
        message: 'Session is already completed',
      );
    }
    session
      ..status = 'COMPLETED'
      ..completedAt = DateTime.now().toUtc();
    return _toJson(session);
  }

  _MockSession _find(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) {
      throw const ApiException(statusCode: 404, message: 'Session not found');
    }
    return session;
  }

  _MockQuestion _question(_MockSession session, String questionId) {
    for (final question in session.questions) {
      if (question.questionId == questionId) return question;
    }
    throw const ApiException(statusCode: 404, message: 'Question not found');
  }

  /// The API's Session object. Reveal rule: answered in IMMEDIATE mode, or
  /// any question once the session is completed.
  Json _toJson(_MockSession session) {
    final completed = session.status == 'COMPLETED';
    bool revealed(_MockQuestion q) =>
        completed ||
        (session.feedbackMode == FeedbackMode.immediate &&
            q.answeredAt != null);
    bool? isCorrect(_MockQuestion q) => revealed(q) && q.answeredAt != null
        ? q.selectedChoiceId == q.correctChoiceId
        : null;
    final answered = session.questions.where((q) => q.answeredAt != null);
    return {
      'id': session.id,
      'userId': 'mock-user',
      'status': session.status,
      'feedbackMode': feedbackModeToWire(session.feedbackMode),
      'topicIds': [session.topicId],
      'difficulty': null,
      'requestedCount': session.questions.length,
      'createdAt': session.createdAt.toIso8601String(),
      'updatedAt': session.createdAt.toIso8601String(),
      'completedAt': session.completedAt?.toIso8601String(),
      'progress': {
        'total': session.questions.length,
        'answered': answered.length,
        'flagged': session.questions.where((q) => q.isFlagged).length,
        'correct': answered.where((q) => isCorrect(q) == true).length,
      },
      'questions': [
        for (final q in session.questions)
          {
            'id': '${session.id}-${q.order}',
            'questionId': q.questionId,
            'order': q.order,
            'isFlagged': q.isFlagged,
            'answeredAt': q.answeredAt?.toIso8601String(),
            'timeSpentSeconds': q.timeSpentSeconds,
            'selectedChoiceId': q.selectedChoiceId,
            'isCorrect': isCorrect(q),
            'question': {
              'id': q.questionId,
              'text': q.text,
              'topic': {
                'id': q.topicId,
                'name': q.topicName,
                'description': null,
              },
              'code': q.order + 1,
              'losCode': null,
              'difficulty': q.order % 3 == 0 ? 'MEDIUM' : null,
              'explanation': revealed(q)
                  ? 'Sample explanation for question ${q.order + 1}.'
                  : null,
            },
            'choices': [
              for (final choice in q.choices)
                {
                  'id': choice.id,
                  'text': choice.text,
                  if (revealed(q)) 'isCorrect': choice.id == q.correctChoiceId,
                },
            ],
          },
      ],
    };
  }
}
