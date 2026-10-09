import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/session/sign_out_hooks.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/providers/auth_state.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _session = AuthSession(
  user: AuthUser(
    id: 'u1',
    email: 'a@b.co',
    firstName: 'A',
    lastName: 'B',
    role: 'USER',
  ),
  accessToken: 'token',
);

void main() {
  late MockAuthRepository repository;
  late ProviderContainer container;
  late List<String> events;

  setUp(() async {
    repository = MockAuthRepository();
    events = [];
    when(() => repository.restoreSession()).thenAnswer((_) async => _session);
    when(() => repository.logout()).thenAnswer((_) async {
      events.add('logout');
    });
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        signOutHooksProvider.overrideWithValue([
          SignOutHook(
            before: () async {
              // The session must still be signed in while the hook runs.
              final state = container.read(authNotifierProvider);
              events.add('hook:${state is AuthAuthenticated}');
            },
            cancelled: () async => events.add('cancelled'),
          ),
        ]),
      ],
    );
    addTearDown(container.dispose);
    container.read(authNotifierProvider);
    await Future<void>.delayed(Duration.zero);
  });

  test('logout runs the hooks while still signed in, then logs out', () async {
    await container.read(authNotifierProvider.notifier).logout();

    expect(events, ['hook:true', 'logout']);
    expect(container.read(authNotifierProvider), isA<AuthUnauthenticated>());
  });

  test(
    'account deletion runs the hooks first, and undoes them on failure',
    () async {
      when(() => repository.deleteAccount('wrong')).thenAnswer(
        (_) async => const Result.failure(
          ValidationFailure('Wrong password', code: 'WRONG_CURRENT_PASSWORD'),
        ),
      );

      await container
          .read(authNotifierProvider.notifier)
          .deleteAccount('wrong');

      expect(events, ['hook:true', 'cancelled']);
      expect(container.read(authNotifierProvider), isA<AuthAuthenticated>());
    },
  );

  test('a hook that hangs or fails never blocks logout', () async {
    final hanging = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
        signOutHooksProvider.overrideWithValue([
          SignOutHook(before: () => Future<void>.error(Exception('offline'))),
        ]),
      ],
    );
    addTearDown(hanging.dispose);
    hanging.read(authNotifierProvider);
    await Future<void>.delayed(Duration.zero);

    await hanging.read(authNotifierProvider.notifier).logout();

    expect(hanging.read(authNotifierProvider), isA<AuthUnauthenticated>());
  });
}
