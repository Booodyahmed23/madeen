import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mobile/features/exam_simulation/presentation/providers/exam_notifier.dart';
import 'package:mobile/features/exam_simulation/presentation/providers/exam_state.dart';

import '../../exam_fixtures.dart';

void main() {
  late FakeExamRepository repository;
  late ProviderContainer container;
  late DateTime now;

  ProviderContainer build(FakeExamRepository repo) {
    repository = repo;
    final c = ProviderContainer(
      overrides: [
        examRepositoryProvider.overrideWithValue(repo),
        examClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    now = DateTime.utc(2026, 10, 8, 10);
    container = build(FakeExamRepository());
  });

  ExamNotifier notifier() => container.read(examNotifierProvider.notifier);
  ExamState state() => container.read(examNotifierProvider);
  ExamActive active() => state() as ExamActive;

  test('a started attempt is active, counting down from the server', () async {
    container = build(FakeExamRepository(remainingSeconds: 299));

    await notifier().startExam(testExamConfig);

    expect(active().remainingSeconds, 299);
    expect(active().currentQuestion.id, 'eq1');
    expect(repository.startedWith.single.topicIds, ['topic-1', 'topic-2']);
  });

  test('a failed start is an error that retry repeats', () async {
    repository.startFailure = const NetworkFailure();
    await notifier().startExam(testExamConfig);
    expect(state(), isA<ExamError>());

    repository.startFailure = null;
    await notifier().retry();
    expect(state(), isA<ExamActive>());
  });

  test('every pick and flag is saved on the server', () async {
    await notifier().startExam(testExamConfig);

    expect(await notifier().selectChoice('eq1-b'), isTrue);
    expect(await notifier().toggleFlag(), isTrue);

    expect(repository.answers.single, (questionId: 'eq1', choiceId: 'eq1-b'));
    expect(repository.flags.single, (questionId: 'eq1', flagged: true));
    expect(active().selectedChoiceForCurrent, 'eq1-b');
    expect(active().isCurrentFlagged, isTrue);
    expect(active().answeredCount, 1);
  });

  test('a pick that fails to save is not kept', () async {
    await notifier().startExam(testExamConfig);
    repository.answerFailure = const NetworkFailure();

    expect(await notifier().selectChoice('eq1-b'), isFalse);

    expect(active().selectedChoiceForCurrent, isNull);
  });

  test('submitting lands on the result derived from the attempt', () async {
    await notifier().startExam(testExamConfig);
    await notifier().selectChoice('eq1-a');

    await notifier().submitExam();

    final completed = state() as ExamCompleted;
    expect(completed.result.correct, 1);
    expect(completed.result.unanswered, 1);
    expect(completed.review, hasLength(2));
  });

  test('a failed submission can be retried (submit is idempotent)', () async {
    await notifier().startExam(testExamConfig);
    repository.submitFailure = const NetworkFailure();

    await notifier().submitExam();
    expect((state() as ExamError).retryFrom, isNotNull);

    repository.submitFailure = null;
    await notifier().retry();
    expect(state(), isA<ExamActive>());
    await notifier().submitExam();
    expect(state(), isA<ExamCompleted>());
    expect(repository.submitCalls, 2);
  });

  test('resync re-bases the countdown on the server', () async {
    container = build(FakeExamRepository(remainingSeconds: 600));
    await notifier().startExam(testExamConfig);

    now = now.add(const Duration(seconds: 30));
    await notifier().resync();

    // The fake server still reports 600 s left: the countdown follows it.
    expect(active().remainingSeconds, 600);
  });

  test('reopening an attempt that already ended shows its result', () async {
    container = build(FakeExamRepository()..submitStatus = 'EXPIRED');
    await repository.submitExam('attempt-1');

    await notifier().reopenAttempt('attempt-1');

    final completed = state() as ExamCompleted;
    expect(completed.result.completionStatus, 'timed_out');
  });

  test('navigation stays within bounds', () async {
    await notifier().startExam(testExamConfig);

    notifier().previousQuestion();
    expect(active().currentIndex, 0);
    notifier().nextQuestion();
    expect(active().currentIndex, 1);
    notifier().nextQuestion();
    expect(active().currentIndex, 1);
    notifier().goToQuestion(0);
    expect(active().currentIndex, 0);
  });
}
