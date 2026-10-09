import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/curriculum/data/repositories/curriculum_repository_impl.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/curriculum/domain/entities/topic.dart';
import 'package:mobile/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:mobile/features/curriculum/presentation/screens/topics_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../curriculum_test_tree.dart';

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

void main() {
  testWidgets('a topic without published questions is shown but disabled', (
    tester,
  ) async {
    final repository = MockCurriculumRepository();
    when(() => repository.getProgramTree('program-1')).thenAnswer(
      (_) async => Result.success(
        testCurriculumTree(
          program: const Program(id: 'program-1', name: 'CMA'),
          topics: const [
            Topic(
              id: 'topic-full',
              subUnitId: 'sub-1',
              name: 'Budgeting',
              publishedQuestionCount: 12,
            ),
            Topic(
              id: 'topic-empty',
              subUnitId: 'sub-1',
              name: 'Forecasting',
              publishedQuestionCount: 0,
            ),
          ],
        ),
      ),
    );
    final opened = <String>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const TopicsScreen(programId: 'program-1', subUnitId: 'sub-1'),
        ),
        GoRoute(
          path: '/curriculum/topics/:topicId',
          builder: (_, state) {
            opened.add(state.pathParameters['topicId']!);
            return const Text('SETUP');
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [curriculumRepositoryProvider.overrideWithValue(repository)],
        retry: appRetryPolicy,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No questions yet'), findsOneWidget);

    await tester.tap(find.text('Forecasting'));
    await tester.pumpAndSettle();
    expect(opened, isEmpty);

    await tester.tap(find.text('Budgeting'));
    await tester.pumpAndSettle();
    expect(opened, ['topic-full']);
  });

  testWidgets('practice all starts one setup with every topic that has '
      'questions', (tester) async {
    final repository = MockCurriculumRepository();
    when(() => repository.getProgramTree('program-1')).thenAnswer(
      (_) async => Result.success(
        testCurriculumTree(
          program: const Program(id: 'program-1', name: 'CMA'),
          topics: const [
            Topic(id: 't1', subUnitId: 'sub-1', name: 'A'),
            Topic(id: 't2', subUnitId: 'sub-1', name: 'B'),
            Topic(
              id: 't3',
              subUnitId: 'sub-1',
              name: 'Empty',
              publishedQuestionCount: 0,
            ),
          ],
        ),
      ),
    );
    Object? opened;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const TopicsScreen(
            programId: 'program-1',
            subUnitId: 'sub-1',
            subUnitName: 'Budgeting',
          ),
        ),
        GoRoute(
          path: AppRoutes.studySessionSetup,
          builder: (_, state) {
            opened = state.extra;
            return const Text('SETUP');
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [curriculumRepositoryProvider.overrideWithValue(repository)],
        retry: appRetryPolicy,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Practice all these topics'));
    await tester.pumpAndSettle();

    final scope = opened as StudySetupScope;
    expect(scope.topicIds, ['t1', 't2']);
    expect(scope.label, 'Budgeting');
  });
}
