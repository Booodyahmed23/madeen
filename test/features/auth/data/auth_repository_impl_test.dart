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

  const response = AuthResponseModel(
    userId: 'user-1',
    email: 'jane@example.com',
    firstName: 'Jane',
    lastName: 'Doe',
    roles: ['USER'],
    accessToken: 'access-token-1',
    refreshToken: 'refresh-token-1',
  );

  setUp(() {
    remote = MockAuthRemoteDataSource();
    secureStorage = MockSecureStorage();
    repository = AuthRepositoryImpl(remote, secureStorage);

    when(() => secureStorage.saveRefreshToken(any())).thenAnswer((_) async {});
    when(() => secureStorage.clear()).thenAnswer((_) async {});
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

  group('getCurrentUser', () {
    test('maps the /users/me profile onto an AuthUser', () async {
      when(() => remote.getCurrentUser()).thenAnswer(
        (_) async => const UserProfileModel(
          id: 'user-1',
          email: 'jane@example.com',
          firstName: 'Janet',
          lastName: 'Doe',
          roles: ['USER'],
        ),
      );

      final result = await repository.getCurrentUser();

      expect((result as Success).value.firstName, 'Janet');
    });

    test('returns a typed failure instead of throwing', () async {
      when(() => remote.getCurrentUser())
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
