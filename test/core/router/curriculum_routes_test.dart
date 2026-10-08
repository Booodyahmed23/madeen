import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/curriculum/data/repositories/curriculum_repository_impl.dart';
import 'package:mobile/features/curriculum/domain/entities/part.dart';
import 'package:mobile/features/curriculum/domain/entities/program.dart';
import 'package:mobile/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_history_page.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/curriculum/curriculum_test_tree.dart';
import '../../features/subscription/access_overrides.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockCurriculumRepository extends Mock implements CurriculumRepository {}

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

class MockPerformanceRepository extends Mock implements PerformanceRepository {}

class MockAiAnalysisRepository extends Mock implements AiAnalysisRepository {}

const _user = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  role: 'USER',
);
const _session = AuthSession(user: _user, accessToken: 'access-token-1');

const _overview = PerformanceOverview(
  totalAttempts: 0,
  questionsPracticed: 0,
  totalAnswered: 0,
  totalCorrect: 0,
  overallScorePercent: 0,
  totalTime: Duration.zero,
  averageTimePerQuestion: Duration.zero,
);

final _insufficientAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.overall,
    status: AiAnalysisStatus.insufficientData,
    generatedAt: DateTime(2026, 9, 16, 9),
    basedOnAttemptCount: 0,
  ),
  overallSummary: 'Complete a Study Session to unlock personalized insights.',
);

void main() {
  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  testWidgets(
    'an unauthenticated user cannot reach /curriculum — redirected to login instead',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession()).thenAnswer((_) async => null);
      final curriculumRepository = MockCurriculumRepository();

      await tester.pumpWidget(
        ProviderScope(
          retry: appRetryPolicy,
          overrides: [
            ...accessOverrides(),
            authRepositoryProvider.overrideWithValue(authRepository),
            curriculumRepositoryProvider.overrideWithValue(
              curriculumRepository,
            ),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      // The router's redirect fires before /curriculum is ever reachable —
      // proven by never calling the curriculum repository at all.
      verifyNever(() => curriculumRepository.getPrograms());
      expect(find.text('Welcome back'), findsOneWidget); // LoginScreen
    },
  );

  testWidgets(
    'an authenticated user can browse from Home -> Programs -> Parts',
    (tester) async {
      tester.view.physicalSize = const Size(800, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession())
          .thenAnswer((_) async => _session);

      final curriculumRepository = MockCurriculumRepository();
      when(() => curriculumRepository.getPrograms()).thenAnswer(
        (_) async =>
            const Result.success([Program(id: 'program-cma', name: 'CMA')]),
      );
      when(() => curriculumRepository.getProgramTree('program-cma')).thenAnswer(
        (_) async => Result.success(
          testCurriculumTree(
            program: const Program(id: 'program-cma', name: 'CMA'),
            parts: const [
              Part(id: 'cma-part-1', programId: 'program-cma', name: 'Part 1'),
            ],
          ),
        ),
      );

      // Home now reads Performance/AI Analysis/Notifications on every
      // build (Performance Snapshot, Recent Activity, AI Analysis teaser,
      // unread badge, Upcoming Reminder) — all three need a minimal stub.
      final notificationsRepository = MockNotificationsRepository();
      when(() => notificationsRepository.getUnreadCount())
          .thenAnswer((_) async => const Result.success(0));
      when(() => notificationsRepository.getStudyReminders())
          .thenAnswer((_) async => const Result.success([]));
      final performanceRepository = MockPerformanceRepository();
      when(
        () => performanceRepository.getOverview(filter: any(named: 'filter')),
      ).thenAnswer((_) async => const Result.success(_overview));
      when(
        () => performanceRepository.getAttempts(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async =>
            const Result.success(AttemptHistoryPage(items: [], hasMore: false)),
      );
      final aiAnalysisRepository = MockAiAnalysisRepository();
      when(
        () => aiAnalysisRepository.getOverallAnalysis(
          filter: any(named: 'filter'),
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_insufficientAnalysis));

      await tester.pumpWidget(
        ProviderScope(
          retry: appRetryPolicy,
          overrides: [
            ...accessOverrides(),
            authRepositoryProvider.overrideWithValue(authRepository),
            curriculumRepositoryProvider.overrideWithValue(
              curriculumRepository,
            ),
            notificationsRepositoryProvider.overrideWithValue(
              notificationsRepository,
            ),
            performanceRepositoryProvider.overrideWithValue(
              performanceRepository,
            ),
            aiAnalysisRepositoryProvider.overrideWithValue(
              aiAnalysisRepository,
            ),
          ],
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      // Home -> Curriculum (the dashboard's Curriculum shortcut card).
      await tester.tap(find.text('Curriculum'));
      await tester.pumpAndSettle();
      expect(find.text('Programs'), findsOneWidget);
      expect(find.text('CMA'), findsOneWidget);

      // Programs -> Parts
      await tester.tap(find.text('CMA'));
      await tester.pumpAndSettle();
      expect(find.text('Part 1'), findsOneWidget);
      // Immediate-parent context, not a full breadcrumb chain.
      expect(find.text('in CMA'), findsOneWidget);

      verify(() => curriculumRepository.getProgramTree('program-cma'))
          .called(1);
    },
  );
}
