import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/device_session.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/presentation/screens/signed_in_devices_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

final _sessions = [
  DeviceSession(
    id: 's-current',
    userAgent: 'MADEEN (ios; 18.2)',
    lastActiveAt: DateTime.utc(2026, 10, 9, 12),
    isCurrent: true,
  ),
  DeviceSession(
    id: 's-web',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0) AppleWebKit/537.36 Chrome/131 '
        'Safari/537.36',
    lastActiveAt: DateTime.utc(2026, 10, 8, 9, 30),
    isCurrent: false,
  ),
];

Future<void> _pump(WidgetTester tester, MockAuthRepository repository) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SignedInDevicesScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository();
    when(() => repository.getDeviceSessions())
        .thenAnswer((_) async => Result.success(_sessions));
  });

  testWidgets('lists devices, marking this one', (tester) async {
    await _pump(tester, repository);

    expect(find.text('MADEEN app · iPhone'), findsOneWidget);
    expect(find.text('This device'), findsOneWidget);
    expect(find.text('Chrome · Windows'), findsOneWidget);
    expect(find.textContaining('Last active'), findsOneWidget);
  });

  testWidgets('signing another device out asks, revokes it and reloads', (
    tester,
  ) async {
    when(() => repository.signOutDevice('s-web'))
        .thenAnswer((_) async => const Result.success(null));
    await _pump(tester, repository);

    await tester.tap(find.widgetWithText(TextButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out this device?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    verify(() => repository.signOutDevice('s-web')).called(1);
    verify(() => repository.getDeviceSessions()).called(2);
  });

  testWidgets('sign out all others reports how many', (tester) async {
    when(() => repository.signOutOtherDevices())
        .thenAnswer((_) async => const Result.success(1));
    await _pump(tester, repository);

    await tester.tap(find.text('Sign out all other devices'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('1 device signed out.'), findsOneWidget);
  });

  testWidgets('with only this device, there is nothing else to sign out', (
    tester,
  ) async {
    when(() => repository.getDeviceSessions())
        .thenAnswer((_) async => Result.success([_sessions.first]));
    await _pump(tester, repository);

    expect(find.text('Sign out all other devices'), findsNothing);
  });
}
