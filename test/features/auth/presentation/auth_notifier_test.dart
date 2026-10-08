import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _user = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  roles: ['USER'],
);
const _session = AuthSession(user: _user, accessToken: 'access-token-1');

void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  /// Riverpod providers are lazy — reading `authNotifierProvider` is what
  /// actually triggers `build()` (and, inside it, the fire-and-forget
  /// `_restore()` call). Every test needs that triggered *before* it awaits
  /// a settle, or there is nothing yet to wait on.
  Future<void> initializeAndSettle() async {
    container.read(authNotifierProvider);
    await Future<void>.delayed(Duration.zero);
  }

  test('starts Initializing, then settles on Unauthenticated when there is no stored session', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => null);

    expect(container.read(authNotifierProvider), isA<AuthInitializing>());
    await Future<void>.delayed(Duration.zero);

    expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
  });

  test('settles on Authenticated when a session can be restored', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => _session);

    await initializeAndSettle();

    final state = container.read(authNotifierProvider);
    expect(state, isA<AuthAuthenticated>());
    expect((state as AuthAuthenticated).user.email, 'jane@example.com');
  });

  test('login success transitions Unauthenticated -> Authenticated', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => null);
    await initializeAndSettle();

    when(
      () => repository.login(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => const Result.success(_session));

    final result = await container
        .read(authNotifierProvider.notifier)
        .login(email: 'jane@example.com', password: 'Password123');

    expect(result, isA<Success<dynamic>>());
    expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());
  });

  test(
    'login failure leaves state Unauthenticated and surfaces the failure',
    () async {
      when(() => repository.restoreSession()).thenAnswer((_) async => null);
      await initializeAndSettle();

      when(
        () => repository.login(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer(
        (_) async => const Result.failure(
          UnauthorizedFailure('Invalid email or password'),
        ),
      );

      final result = await container
          .read(authNotifierProvider.notifier)
          .login(email: 'jane@example.com', password: 'wrong');

      expect(result, isA<Failure<dynamic>>());
      expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
    },
  );

  test('logout clears the session and returns to Unauthenticated', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => _session);
    await initializeAndSettle();
    expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());

    when(() => repository.logout()).thenAnswer((_) async {});
    await container.read(authNotifierProvider.notifier).logout();

    expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
  });

  test(
    'accessTokenOrNull reflects the current state for the network interceptor',
    () async {
      when(() => repository.restoreSession()).thenAnswer((_) async => _session);
      await initializeAndSettle();

      expect(
        container.read(authNotifierProvider.notifier).accessTokenOrNull,
        'access-token-1',
      );
    },
  );

  test('silentRefresh drops to Unauthenticated when the stored session can no longer be restored', () async {
    when(() => repository.restoreSession()).thenAnswer((_) async => _session);
    await initializeAndSettle();

    when(() => repository.restoreSession()).thenAnswer((_) async => null);
    final newToken = await container
        .read(authNotifierProvider.notifier)
        .silentRefresh();

    expect(newToken, isNull);
    expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
  });

  group('offline / transient failures at launch', () {
    test(
      'a restore that cannot reach the server settles on SessionUnavailable, '
      'not Unauthenticated',
      () async {
        when(() => repository.restoreSession())
            .thenThrow(const NetworkFailure());

        await initializeAndSettle();

        final state = container.read(authNotifierProvider);
        expect(state, isA<AuthSessionUnavailable>());
        expect(
          (state as AuthSessionUnavailable).failure,
          isA<NetworkFailure>(),
        );
      },
    );

    test(
      'retryRestore recovers the session once the server is reachable',
      () async {
        when(() => repository.restoreSession())
            .thenThrow(const NetworkFailure());
        await initializeAndSettle();

        when(() => repository.restoreSession())
            .thenAnswer((_) async => _session);
        final retry = container
            .read(authNotifierProvider.notifier)
            .retryRestore();
        expect(container.read(authNotifierProvider), isA<AuthInitializing>());
        await retry;

        expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());
      },
    );

    test(
      'logging out from SessionUnavailable discards the stored session',
      () async {
        when(() => repository.restoreSession())
            .thenThrow(const NetworkFailure());
        when(() => repository.logout()).thenAnswer((_) async {});
        await initializeAndSettle();

        await container.read(authNotifierProvider.notifier).logout();

        verify(() => repository.logout()).called(1);
        expect(
          container.read(authNotifierProvider),
          isA<AuthUnauthenticated>(),
        );
      },
    );

    test('unreadable secure storage falls back to sign-in instead of an '
        'endless startup spinner', () async {
      when(() => repository.restoreSession())
          .thenThrow(Exception('keychain unavailable'));

      await initializeAndSettle();

      expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
    });
  });

  group('silentRefresh (used by the network interceptor)', () {
    test('success replaces the access token and returns it', () async {
      when(() => repository.restoreSession()).thenAnswer((_) async => _session);
      await initializeAndSettle();

      when(() => repository.restoreSession()).thenAnswer(
        (_) async =>
            const AuthSession(user: _user, accessToken: 'access-token-2'),
      );
      final token = await container
          .read(authNotifierProvider.notifier)
          .silentRefresh();

      expect(token, 'access-token-2');
      expect(
        container.read(authNotifierProvider.notifier).accessTokenOrNull,
        'access-token-2',
      );
    });

    test(
      'a transient failure rethrows and leaves the session signed in',
      () async {
        when(() => repository.restoreSession())
            .thenAnswer((_) async => _session);
        await initializeAndSettle();

        when(() => repository.restoreSession())
            .thenThrow(const NetworkFailure());

        await expectLater(
          container.read(authNotifierProvider.notifier).silentRefresh(),
          throwsA(isA<NetworkFailure>()),
        );
        expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());
      },
    );
  });

  test(
    'logout signs out immediately, without waiting for the server',
    () async {
      when(() => repository.restoreSession()).thenAnswer((_) async => _session);
      await initializeAndSettle();

      final serverRevoke = Completer<void>();
      when(() => repository.logout()).thenAnswer((_) => serverRevoke.future);
      final pending = container.read(authNotifierProvider.notifier).logout();

      expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
      serverRevoke.complete();
      await pending;
    },
  );

  group('profile', () {
    const renamed = AuthUser(
      id: 'user-1',
      email: 'jane@example.com',
      firstName: 'Janet',
      lastName: 'Doe',
      roles: ['USER'],
    );

    test('refreshCurrentUser updates the signed-in user', () async {
      when(() => repository.restoreSession()).thenAnswer((_) async => _session);
      when(() => repository.getCurrentUser())
          .thenAnswer((_) async => const Result.success(renamed));
      await initializeAndSettle();

      await container.read(authNotifierProvider.notifier).refreshCurrentUser();

      final state = container.read(authNotifierProvider) as AuthAuthenticated;
      expect(state.user.firstName, 'Janet');
      expect(state.accessToken, 'access-token-1', reason: 'token untouched');
    });

    test('a failed refreshCurrentUser keeps the cached user', () async {
      when(() => repository.restoreSession()).thenAnswer((_) async => _session);
      when(() => repository.getCurrentUser())
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));
      await initializeAndSettle();

      final result = await container
          .read(authNotifierProvider.notifier)
          .refreshCurrentUser();

      expect(result, isA<Failure<AuthUser>>());
      final state = container.read(authNotifierProvider) as AuthAuthenticated;
      expect(state.user.firstName, 'Jane');
    });

    test('updateProfile success updates the signed-in user', () async {
      when(() => repository.restoreSession()).thenAnswer((_) async => _session);
      when(
        () => repository.updateProfile(
          firstName: any(named: 'firstName'),
          lastName: any(named: 'lastName'),
        ),
      ).thenAnswer((_) async => const Result.success(renamed));
      await initializeAndSettle();

      await container
          .read(authNotifierProvider.notifier)
          .updateProfile(firstName: 'Janet', lastName: 'Doe');

      final state = container.read(authNotifierProvider) as AuthAuthenticated;
      expect(state.user.firstName, 'Janet');
    });
  });
}
