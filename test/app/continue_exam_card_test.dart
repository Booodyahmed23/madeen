import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/widgets/continue_exam_card.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/exam_simulation/data/models/exam_attempt_model.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mobile/features/exam_simulation/domain/entities/exam_attempt.dart';
import 'package:mobile/features/exam_simulation/presentation/providers/exam_notifier.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

import '../features/exam_simulation/exam_fixtures.dart';

Future<void> _pump(
  WidgetTester tester,
  FakeExamRepository repository,
  List<ExamAttemptSummary> open,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: ContinueExamCard()),
      ),
      GoRoute(
        path: AppRoutes.examActive,
        builder: (_, _) => const Text('ACTIVE'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        examRepositoryProvider.overrideWithValue(repository),
        examClockProvider.overrideWithValue(
          () => examStartedAt.add(const Duration(minutes: 3)),
        ),
        unfinishedExamAttemptsProvider.overrideWith((ref) async => open),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows nothing without a running attempt', (tester) async {
    await _pump(tester, FakeExamRepository(), const []);

    expect(find.text('Continue your exam'), findsNothing);
  });

  testWidgets('continues a running attempt, with the minutes left', (
    tester,
  ) async {
    final summary = examAttemptSummaryFromJson(
      fakeAttemptJson()..remove('questions'),
    );
    await _pump(tester, FakeExamRepository(), [summary]);

    expect(find.text('Continue your exam'), findsOneWidget);
    // 15-minute attempt, 3 minutes in.
    expect(find.text('2 questions · 12 min left'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE'), findsOneWidget);
  });
}
