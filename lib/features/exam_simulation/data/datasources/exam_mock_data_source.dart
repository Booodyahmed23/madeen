import '../../../../core/network/api_exception.dart';
import '../../domain/entities/exam_config.dart';
import 'exam_data_source.dart';

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

class _MockAttempt {
  _MockAttempt({
    required this.id,
    required this.durationMinutes,
    required this.topicIds,
    required this.questions,
    required this.startedAt,
  });

  final String id;
  final int durationMinutes;
  final List<String> topicIds;
  final List<_MockQuestion> questions;
  final DateTime startedAt;
  String status = 'IN_PROGRESS';
  DateTime? submittedAt;

  DateTime get expiresAt => startedAt.add(Duration(minutes: durationMinutes));
}

/// Local sample exam, used while `EXAM_SIMULATION_API_AVAILABLE` is off. An
/// in-memory stand-in for the API: it keeps attempts, owns the clock (an
/// attempt touched after it expires turns `EXPIRED`), reveals every
/// question once the attempt ends, and returns the same JSON as the real
/// endpoints. A UI-development aid, **not** production exam content.
class ExamMockDataSource implements ExamDataSource {
  ExamMockDataSource({
    this.delay = const Duration(milliseconds: 400),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Duration delay;
  final DateTime Function() _clock;

  static const _choiceLetters = ['A', 'B', 'C', 'D'];

  final _attempts = <String, _MockAttempt>{};
  var _counter = 0;

  DateTime get _now => _clock().toUtc();

  @override
  Future<Json> startExam(ExamConfig config) async {
    await Future<void>.delayed(delay);
    final topicIds = config.topicIds.isEmpty
        ? [config.subUnitId ?? config.unitId ?? config.partId]
        : config.topicIds;
    final attemptId = 'mock-attempt-${_counter++}';
    final questions = List.generate(config.questionCount, (index) {
      final questionId = '$attemptId-q$index';
      final topicId = topicIds[index % topicIds.length];
      final choices = [
        for (var c = 0; c < _choiceLetters.length; c++)
          (
            id: '$questionId-choice-$c',
            text: '${_choiceLetters[c]}) Sample option ${c + 1}',
          ),
      ];
      return _MockQuestion(
        questionId: questionId,
        order: index,
        text: 'Sample exam question ${index + 1}.',
        topicId: topicId,
        topicName:
            config.topicNames[topicId] ??
            config.subUnitName ??
            config.unitName ??
            config.partName,
        choices: choices,
        correctChoiceId: choices[(index * 3) % choices.length].id,
      );
    });
    final attempt = _MockAttempt(
      id: attemptId,
      durationMinutes: config.durationMinutes,
      topicIds: topicIds,
      questions: questions,
      startedAt: _now,
    );
    _attempts[attemptId] = attempt;
    return _toJson(attempt);
  }

  @override
  Future<Json> getAttempt(String attemptId) async {
    await Future<void>.delayed(delay);
    return _toJson(_find(attemptId));
  }

  @override
  Future<Json> listAttempts({required int page, required int limit}) async {
    final all = _attempts.values.toList().reversed.toList();
    return {
      'data': [
        for (final attempt in all.skip((page - 1) * limit).take(limit))
          _toJson(attempt)..remove('questions'),
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
    required String attemptId,
    required String questionId,
    required String choiceId,
    int? timeSpentSeconds,
  }) async {
    await Future<void>.delayed(delay);
    final attempt = _openAttempt(attemptId);
    _question(attempt, questionId)
      ..selectedChoiceId = choiceId
      ..answeredAt = _now
      ..timeSpentSeconds += timeSpentSeconds ?? 0;
    return _toJson(attempt);
  }

  @override
  Future<Json> flagQuestion({
    required String attemptId,
    required String questionId,
    required bool flagged,
  }) async {
    await Future<void>.delayed(delay);
    final attempt = _openAttempt(attemptId);
    _question(attempt, questionId).isFlagged = flagged;
    return _toJson(attempt);
  }

  @override
  Future<Json> submitExam(String attemptId) async {
    await Future<void>.delayed(delay);
    final attempt = _find(attemptId);
    if (attempt.status == 'IN_PROGRESS') {
      attempt
        ..status = 'SUBMITTED'
        ..submittedAt = _now;
    }
    return _toJson(attempt);
  }

  /// Applies the server-side clock: past `expiresAt`, an in-progress
  /// attempt becomes `EXPIRED`.
  _MockAttempt _find(String attemptId) {
    final attempt = _attempts[attemptId];
    if (attempt == null) {
      throw const ApiException(statusCode: 404, message: 'Attempt not found');
    }
    if (attempt.status == 'IN_PROGRESS' && !_now.isBefore(attempt.expiresAt)) {
      attempt
        ..status = 'EXPIRED'
        ..submittedAt = attempt.expiresAt;
    }
    return attempt;
  }

  _MockAttempt _openAttempt(String attemptId) {
    final attempt = _find(attemptId);
    if (attempt.status != 'IN_PROGRESS') {
      throw const ApiException(
        statusCode: 400,
        message: 'Attempt is not in progress',
      );
    }
    return attempt;
  }

  _MockQuestion _question(_MockAttempt attempt, String questionId) {
    for (final question in attempt.questions) {
      if (question.questionId == questionId) return question;
    }
    throw const ApiException(statusCode: 404, message: 'Question not found');
  }

  Json _toJson(_MockAttempt attempt) {
    final ended = attempt.status != 'IN_PROGRESS';
    final answered = attempt.questions.where((q) => q.answeredAt != null);
    final correct = answered
        .where((q) => q.selectedChoiceId == q.correctChoiceId)
        .length;
    final remaining = attempt.expiresAt.difference(_now).inSeconds;
    return {
      'id': attempt.id,
      'userId': 'mock-user',
      'status': attempt.status,
      'durationMinutes': attempt.durationMinutes,
      'topicIds': attempt.topicIds,
      'difficulty': null,
      'requestedCount': attempt.questions.length,
      'startedAt': attempt.startedAt.toIso8601String(),
      'expiresAt': attempt.expiresAt.toIso8601String(),
      'submittedAt': attempt.submittedAt?.toIso8601String(),
      'createdAt': attempt.startedAt.toIso8601String(),
      'updatedAt': attempt.startedAt.toIso8601String(),
      'remainingSeconds': ended ? 0 : remaining.clamp(0, 1 << 31),
      'progress': {
        'total': attempt.questions.length,
        'answered': answered.length,
        'flagged': attempt.questions.where((q) => q.isFlagged).length,
      },
      'score': ended
          ? {
              'correct': correct,
              'incorrect': answered.length - correct,
              'unanswered': attempt.questions.length - answered.length,
            }
          : null,
      'questions': [
        for (final q in attempt.questions)
          {
            'id': '${attempt.id}-${q.order}',
            'questionId': q.questionId,
            'order': q.order,
            'isFlagged': q.isFlagged,
            'answeredAt': q.answeredAt?.toIso8601String(),
            'timeSpentSeconds': q.timeSpentSeconds,
            'selectedChoiceId': q.selectedChoiceId,
            'isCorrect': ended && q.answeredAt != null
                ? q.selectedChoiceId == q.correctChoiceId
                : null,
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
              'difficulty': 'MEDIUM',
              'explanation': ended
                  ? 'Sample explanation for question ${q.order + 1}.'
                  : null,
            },
            'choices': [
              for (final choice in q.choices)
                {
                  'id': choice.id,
                  'text': choice.text,
                  if (ended) 'isCorrect': choice.id == q.correctChoiceId,
                },
            ],
          },
      ],
    };
  }
}
