import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/curriculum/data/repositories/curriculum_repository_impl.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:mobile/features/curriculum/presentation/screens/programs_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

Widget _wrap(CurriculumRepository repository) {
  return ProviderScope(
    overrides: [curriculumRepositoryProvider.overrideWithValue(repository)],
    retry: appRetryPolicy,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ProgramsScreen(),
    ),
  );
}

void main() {
  testWidgets('shows a loading indicator while programs are being fetched', (
    tester,
  ) async {
    final repository = MockCurriculumRepository();
    // A manually-controlled Completer, not a real Timer/Future.delayed —
    // leaving a real timer pending past the end of a test trips
    // flutter_test's "Pending timers" invariant check and, worse, can bleed
    // into later tests. Completed explicitly at the end of this test.
    final completer = Completer<Result<List<Program>>>();
    when(() => repository.getPrograms()).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repository));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(const Result.success([]));
    await tester.pumpAndSettle();
  });

  testWidgets('shows each program once loaded', (tester) async {
    final repository = MockCurriculumRepository();
    when(() => repository.getPrograms()).thenAnswer(
      (_) async => const Result.success([
        Program(id: 'program-cma', name: 'CMA', code: 'CMA'),
        Program(id: 'program-fmaa', name: 'FMAA', code: 'FMAA'),
      ]),
    );

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('CMA'), findsOneWidget);
    expect(find.text('FMAA'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no programs', (
    tester,
  ) async {
    final repository = MockCurriculumRepository();
    when(() => repository.getPrograms())
        .thenAnswer((_) async => const Result.success([]));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(find.text('No programs are available yet.'), findsOneWidget);
  });

  testWidgets('shows a localized error message and a retry button on failure', (
    tester,
  ) async {
    final repository = MockCurriculumRepository();
    when(() => repository.getPrograms())
        .thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );
    expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
  });

  testWidgets('retry re-fetches after a failure', (tester) async {
    final repository = MockCurriculumRepository();
    var callCount = 0;
    when(() => repository.getPrograms()).thenAnswer((_) async {
      callCount++;
      if (callCount == 1) return const Result.failure(NetworkFailure());
      return const Result.success([
        Program(id: 'program-cma', name: 'CMA', code: 'CMA'),
      ]);
    });

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();
    expect(
      find.text("Can't reach the server. Check your connection and try again."),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.text('CMA'), findsOneWidget);
    expect(callCount, 2);
  });
}
