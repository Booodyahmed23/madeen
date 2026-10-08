import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/core/storage/secure_storage.dart';
import 'package:mobile/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockSecureStorage extends Mock implements SecureStorage {}

void main() {
  late MockAuthRemoteDataSource remote;
  late MockSecureStorage secureStorage;
  late AuthRepositoryImpl repository;

  const response = AuthTokensModel(
    accessToken: 'access-token-1',
    refreshToken: 'refresh-token-1',
  );
  const profile = UserProfileModel(
    id: 'user-1',
    email: 'jane@example.com',
    firstName: 'Jane',
    lastName: 'Doe',
    role: 'USER',
  );

  setUp(() {
    remote = MockAuthRemoteDataSource();
    secureStorage = MockSecureStorage();
    repository = AuthRepositoryImpl(remote, secureStorage);

    when(() => secureStorage.saveRefreshToken(any())).thenAnswer((_) async {});
    when(() => secureStorage.clear()).thenAnswer((_) async {});
    when(() => remote.getCurrentUser(accessToken: any(named: 'accessToken')))
        .thenAnswer((_) async => profile);
  });

  group('register / login', () {
    test(
      'register persists the refresh token and returns a mapped session',
      () async {
        when(
          () => remote.register(
            firstName: any(named: 'firstName'),
            lastName: any(named: 'lastName'),
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => response);

        final result = await repository.register(
          firstName: 'Jane',
          lastName: 'Doe',
          email: 'jane@example.com',
          password: 'Password123',
        );

        expect(result, isA<Success<dynamic>>());
        final session = (result as Success).value;
        expect(session.user.email, 'jane@example.com');
        expect(session.accessToken, 'access-token-1');
        verify(() => secureStorage.saveRefreshToken('refresh-token-1'))
            .called(1);
        // Register returns no user: it is loaded with the new token.
        verify(() => remote.getCurrentUser(accessToken: 'access-token-1'))
            .called(1);
      },
    );

    test(
      'login maps a 409 duplicate-email-style error onto ConflictFailure',
      () async {
        when(
          () => remote.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiException(
            statusCode: 409,
            message: 'An account with this email already exists',
          ),
        );

        final result = await repository.login(
          email: 'jane@example.com',
          password: 'x',
        );

        expect(result, isA<Failure<dynamic>>());
        expect((result as Failure).failure, isA<ConflictFailure>());
      },
    );

    test(
      'login maps a 401 onto UnauthorizedFailure with the backend message',
      () async {
        when(
          () => remote.login(
            email: any(named: 'email'),
            password: any(named: 'password'),
          ),
        ).thenThrow(
          const ApiException(
            statusCode: 401,
            message: 'Invalid email or password',
          ),
        );

        final result = await repository.login(
          email: 'jane@example.com',
          password: 'wrong',
        );

        expect(result, isA<Failure<dynamic>>());
        final failure = (result as Failure).failure;
        expect(failure, isA<UnauthorizedFailure>());
        expect(failure.message, 'Invalid email or password');
      },
    );
  });

  group('restoreSession', () {
    test(
      'returns null without calling the network when nothing is stored',
      () async {
        when(() => secureStorage.readRefreshToken())
            .thenAnswer((_) async => null);

        final session = await repository.restoreSession();

        expect(session, isNull);
        verifyNever(() => remote.refresh(any()));
      },
    );

    test('restores a session by refreshing the stored token', () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'stored-refresh');
      when(() => remote.refresh('stored-refresh'))
          .thenAnswer((_) async => response);

      final session = await repository.restoreSession();

      expect(session, isNotNull);
      expect(session!.user.id, 'user-1');
      verify(() => secureStorage.saveRefreshToken('refresh-token-1')).called(1);
      verify(() => remote.getCurrentUser(accessToken: 'access-token-1'))
          .called(1);
    });

    test('a failed profile load after a good refresh keeps the rotated '
        'token and throws', () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'stored-refresh');
      when(() => remote.refresh('stored-refresh'))
          .thenAnswer((_) async => response);
      when(() => remote.getCurrentUser(accessToken: any(named: 'accessToken')))
          .thenThrow(const ApiException(statusCode: 0, message: 'offline'));

      await expectLater(
        repository.restoreSession(),
        throwsA(isA<NetworkFailure>()),
      );
      verify(() => secureStorage.saveRefreshToken('refresh-token-1')).called(1);
      verifyNever(() => secureStorage.clear());
    });

    test('clears storage and returns null when the stored token is no longer valid', () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'stale-refresh');
      when(() => remote.refresh('stale-refresh')).thenThrow(
        const ApiException(statusCode: 401, message: 'Session expired'),
      );

      final session = await repository.restoreSession();

      expect(session, isNull);
      verify(() => secureStorage.clear()).called(1);
    });

    test(
      'a malformed/revoked token (400) is also treated as session over',
      () async {
        when(() => secureStorage.readRefreshToken())
            .thenAnswer((_) async => 'garbage');
        when(
          () => remote.refresh('garbage'),
        ).thenThrow(const ApiException(statusCode: 400, message: 'Bad token'));

        expect(await repository.restoreSession(), isNull);
        verify(() => secureStorage.clear()).called(1);
      },
    );

    for (final (label, status, failureType) in [
      ('offline (no response)', 0, NetworkFailure),
      ('a server error', 503, ServerFailure),
      ('rate limiting', 429, ServerFailure),
      ('a request timeout', 408, ServerFailure),
    ]) {
      test(
        '$label throws ${failureType.toString()} and KEEPS the stored session',
        () async {
          when(() => secureStorage.readRefreshToken())
              .thenAnswer((_) async => 'stored-refresh');
          when(
            () => remote.refresh('stored-refresh'),
          ).thenThrow(ApiException(statusCode: status, message: 'transient'));

          await expectLater(
            repository.restoreSession(),
            throwsA(
              isA<AppFailure>().having(
                (f) => f.runtimeType,
                'type',
                failureType,
              ),
            ),
          );
          // Regression: this used to clear storage, permanently signing the
          // user out after a single offline launch.
          verifyNever(() => secureStorage.clear());
        },
      );
    }
  });

  group('refreshAccessToken', () {
    test('rotates the stored token without reloading the user', () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'stored-refresh');
      when(() => remote.refresh('stored-refresh'))
          .thenAnswer((_) async => response);

      expect(await repository.refreshAccessToken(), 'access-token-1');
      verify(() => secureStorage.saveRefreshToken('refresh-token-1')).called(1);
      verifyNever(
        () => remote.getCurrentUser(accessToken: any(named: 'accessToken')),
      );
    });
  });

  group('changePassword', () {
    test(
      'saves the new refresh token and returns the new access token',
      () async {
        when(
          () => remote.changePassword(
            currentPassword: 'old-pass',
            newPassword: 'new-pass-123',
          ),
        ).thenAnswer(
          (_) async => const AuthTokensModel(
            accessToken: 'access-2',
            refreshToken: 'refresh-2',
          ),
        );

        final result = await repository.changePassword(
          currentPassword: 'old-pass',
          newPassword: 'new-pass-123',
        );

        expect((result as Success).value, 'access-2');
        verify(() => secureStorage.saveRefreshToken('refresh-2')).called(1);
      },
    );

    test('keeps the WRONG_CURRENT_PASSWORD code', () async {
      when(
        () => remote.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenThrow(
        const ApiException(
          statusCode: 400,
          message: 'Current password is incorrect',
          code: 'WRONG_CURRENT_PASSWORD',
        ),
      );

      final result = await repository.changePassword(
        currentPassword: 'x',
        newPassword: 'new-pass-123',
      );

      final failure = (result as Failure).failure;
      expect(failure, isA<ValidationFailure>());
      expect(failure.code, 'WRONG_CURRENT_PASSWORD');
      verifyNever(() => secureStorage.saveRefreshToken(any()));
    });
  });

  group('deleteAccount', () {
    test('clears the local session and never calls logout', () async {
      when(() => remote.deleteAccount('pass')).thenAnswer((_) async {});

      final result = await repository.deleteAccount('pass');

      expect(result, isA<Success<void>>());
      verify(() => secureStorage.clear()).called(1);
      verifyNever(() => remote.logout(any()));
    });

    test('keeps the session when the password is wrong', () async {
      when(() => remote.deleteAccount(any())).thenThrow(
        const ApiException(
          statusCode: 400,
          message: 'Wrong password',
          code: 'WRONG_CURRENT_PASSWORD',
        ),
      );

      final result = await repository.deleteAccount('nope');

      expect((result as Failure).failure.code, 'WRONG_CURRENT_PASSWORD');
      verifyNever(() => secureStorage.clear());
    });
  });

  group('resetPassword', () {
    test('clears the local session (the server revoked all of them)', () async {
      when(
        () => remote.confirmPasswordReset(
          token: 'tok',
          newPassword: 'new-pass-123',
        ),
      ).thenAnswer((_) async {});

      final result = await repository.resetPassword(
        token: 'tok',
        newPassword: 'new-pass-123',
      );

      expect(result, isA<Success<void>>());
      verify(() => secureStorage.clear()).called(1);
    });
  });

  group('getCurrentUser', () {
    test('maps the /auth/me profile onto an AuthUser', () async {
      when(() => remote.getCurrentUser(accessToken: any(named: 'accessToken')))
          .thenAnswer(
            (_) async => const UserProfileModel(
              id: 'user-1',
              email: 'jane@example.com',
              firstName: 'Janet',
              lastName: 'Doe',
              role: 'USER',
            ),
          );

      final result = await repository.getCurrentUser();

      expect((result as Success).value.firstName, 'Janet');
    });

    test('returns a typed failure instead of throwing', () async {
      when(() => remote.getCurrentUser(accessToken: any(named: 'accessToken')))
          .thenThrow(const ApiException(statusCode: 0, message: 'offline'));

      final result = await repository.getCurrentUser();

      expect((result as Failure).failure, isA<NetworkFailure>());
    });
  });

  group('logout (secure logout behavior)', () {
    test('revokes the server-side session and clears local storage', () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'refresh-token-1');
      when(() => remote.logout(any())).thenAnswer((_) async {});

      await repository.logout();

      verify(() => remote.logout('refresh-token-1')).called(1);
      verify(() => secureStorage.clear()).called(1);
    });

    test('still clears local storage even if the server call fails', () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'refresh-token-1');
      when(() => remote.logout(any()))
          .thenThrow(const ApiException(statusCode: 0, message: 'offline'));

      await repository.logout();

      // A user must never be left "stuck logged in" locally just because
      // the revoke call couldn't reach the server (ARCHITECTURE.md §7).
      verify(() => secureStorage.clear()).called(1);
    });

    test('skips the server call when no refresh token is stored', () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => null);

      await repository.logout();

      verify(() => secureStorage.clear()).called(1);
      verifyNever(() => remote.logout(any()));
    });

    test('clears local storage BEFORE the server call, so a hung revoke never '
        'leaves the device signed in', () async {
      when(() => secureStorage.readRefreshToken())
          .thenAnswer((_) async => 'refresh-token-1');
      when(() => remote.logout(any())).thenAnswer((_) async {});

      await repository.logout();

      verifyInOrder([
        () => secureStorage.readRefreshToken(),
        () => secureStorage.clear(),
        () => remote.logout('refresh-token-1'),
      ]);
    });
  });
}
