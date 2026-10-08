import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/widgets/continue_study_card.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/curriculum/presentation/providers/curriculum_providers.dart';
import 'package:mobile/features/study_session/data/repositories/study_session_repository_impl.dart';
import 'package:mobile/features/study_session/domain/entities/session_config.dart';
import 'package:mobile/features/study_session/domain/entities/study_session.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mobile/features/study_session/presentation/providers/study_session_notifier.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../features/study_session/study_session_fixtures.dart';

class MockStudySessionRepository extends Mock
    implements StudySessionRepository {}

final _unfinished = StudySessionSummary(
  id: 'sess-1',
  status: StudySessionStatus.paused,
  feedbackMode: FeedbackMode.immediate,
  topicIds: const ['topic-1'],
  requestedCount: 20,
  createdAt: DateTime.utc(2026, 10, 8),
);

Future<void> _pump(
  WidgetTester tester,
  MockStudySessionRepository repository,
  List<StudySessionSummary> unfinished,
) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: ContinueStudyCard()),
      ),
      GoRoute(
        path: AppRoutes.studySessionActive,
        builder: (_, _) => const Text('ACTIVE'),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        studySessionRepositoryProvider.overrideWithValue(repository),
        unfinishedStudySessionsProvider.overrideWith((ref) async => unfinished),
        topicNameProvider.overrideWith((ref, id) async => 'Budgeting'),
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
  testWidgets('shows nothing without an unfinished session', (tester) async {
    await _pump(tester, MockStudySessionRepository(), const []);

    expect(find.text('Continue studying'), findsNothing);
  });

  testWidgets('continues the newest unfinished session', (tester) async {
    final repository = MockStudySessionRepository();
    when(() => repository.getSession('sess-1'))
        .thenAnswer((_) async => Result.success(fakeSession(status: 'PAUSED')));
    when(() => repository.resumeSession('sess-1'))
        .thenAnswer((_) async => Result.success(fakeSession()));
    await _pump(tester, repository, [_unfinished]);

    expect(find.text('Continue studying'), findsOneWidget);
    expect(find.text('20 questions · Budgeting'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('ACTIVE'), findsOneWidget);
    verify(() => repository.resumeSession('sess-1')).called(1);
  });
}
