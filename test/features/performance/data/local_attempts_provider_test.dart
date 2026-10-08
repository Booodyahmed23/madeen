import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:mobile/features/performance/data/datasources/performance_local_data_source.dart';
import 'package:mobile/features/performance/data/local_attempts_provider.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mocktail/mocktail.dart';

import '../local_attempt_test_data.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

AuthSession _sessionFor(String id) => AuthSession(
  user: AuthUser(
    id: id,
    email: '$id@example.com',
    firstName: id,
    lastName: 'Test',
    roles: const ['USER'],
  ),
  accessToken: 'token-$id',
);

void main() {
  late MockAuthRepository auth;

  setUp(() {
    auth = MockAuthRepository();
    when(() => auth.logout()).thenAnswer((_) async {});
  });

  /// A fresh container signed in as [userId] (or signed out), with local
  /// attempts restored — i.e. one "app launch".
  Future<ProviderContainer> launch(String? userId) async {
    when(() => auth.restoreSession())
        .thenAnswer((_) async => userId == null ? null : _sessionFor(userId));
    final container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    container.read(localAttemptsProvider);
    await pumpEventQueue();
    container.read(localAttemptsProvider);
    await pumpEventQueue();
    return container;
  }

  test('signed out: empty, and recording is a no-op', () async {
    final container = await launch(null);

    await container.read(localAttemptsProvider.notifier).record(studyRecord());

    expect(container.read(localAttemptsProvider), isEmpty);
  });

  test('record adds newest-first and persists', () async {
    final container = await launch('user-a');
    final notifier = container.read(localAttemptsProvider.notifier);

    await notifier.record(
      studyRecord(id: 'old', completedAt: DateTime(2026, 10, 1)),
    );
    await notifier.record(
      examRecord(id: 'new', completedAt: DateTime(2026, 10, 2)),
    );

    expect(container.read(localAttemptsProvider).map((r) => r.attemptId), [
      'new',
      'old',
    ]);
    final stored = await PerformanceLocalDataSource().load('user-a');
    expect(stored, hasLength(2));
  });

  test('recording the same attempt id twice keeps one copy', () async {
    final container = await launch('user-a');
    final notifier = container.read(localAttemptsProvider.notifier);

    await notifier.record(studyRecord(id: 'same'));
    await notifier.record(studyRecord(id: 'same'));

    expect(container.read(localAttemptsProvider), hasLength(1));
  });

  test('restores the stored history on build (app relaunch)', () async {
    final first = await launch('user-a');
    await first
        .read(localAttemptsProvider.notifier)
        .record(studyRecord(id: 'kept'));
    first.dispose();

    final relaunched = await launch('user-a');

    expect(relaunched.read(localAttemptsProvider).single.attemptId, 'kept');
  });

  test(
    'a record made while the stored history is still loading is kept',
    () async {
      await PerformanceLocalDataSource().save('user-a', [
        studyRecord(id: 'stored', completedAt: DateTime(2026, 10, 1)),
      ]);
      when(() => auth.restoreSession())
          .thenAnswer((_) async => _sessionFor('user-a'));
      final container = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      container.read(authNotifierProvider);
      await pumpEventQueue();

      // Record immediately after build, before the restore has completed.
      container.read(localAttemptsProvider);
      await container
          .read(localAttemptsProvider.notifier)
          .record(studyRecord(id: 'fresh', completedAt: DateTime(2026, 10, 2)));

      expect(container.read(localAttemptsProvider).map((r) => r.attemptId), [
        'fresh',
        'stored',
      ]);
    },
  );

  test(
    'logout hides the history without deleting it; same user gets it back',
    () async {
      final container = await launch('user-a');
      await container
          .read(localAttemptsProvider.notifier)
          .record(studyRecord(id: 'a1'));

      await container.read(authNotifierProvider.notifier).logout();
      await pumpEventQueue();
      expect(container.read(localAttemptsProvider), isEmpty);
      expect(await PerformanceLocalDataSource().load('user-a'), hasLength(1));

      when(
        () => auth.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => Result.success(_sessionFor('user-a')));
      await container
          .read(authNotifierProvider.notifier)
          .login(email: 'user-a@example.com', password: 'Password1');
      container.read(localAttemptsProvider);
      await pumpEventQueue();

      expect(container.read(localAttemptsProvider).single.attemptId, 'a1');
    },
  );

  test('switching to another user shows only that user\'s history', () async {
    final container = await launch('user-a');
    await container
        .read(localAttemptsProvider.notifier)
        .record(studyRecord(id: 'a1'));
    await container.read(authNotifierProvider.notifier).logout();

    when(
      () => auth.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Result.success(_sessionFor('user-b')));
    await container
        .read(authNotifierProvider.notifier)
        .login(email: 'user-b@example.com', password: 'Password1');
    container.read(localAttemptsProvider);
    await pumpEventQueue();

    expect(container.read(localAttemptsProvider), isEmpty);
    await container
        .read(localAttemptsProvider.notifier)
        .record(studyRecord(id: 'b1'));
    expect(container.read(localAttemptsProvider).single.attemptId, 'b1');
    expect(
      (await PerformanceLocalDataSource().load('user-a')).single.attemptId,
      'a1',
    );
  });
}
