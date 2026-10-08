// Foundation smoke test: the app boots, resolves its default locale/theme,
// and renders the (now auth-gated) home screen without throwing.
// authRepositoryProvider is overridden with a fake so this never touches
// real secure storage or the network — see router_auth_redirect_test.dart
// for the auth-gating behavior itself.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mobile/app/app.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_history_page.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';

import 'features/subscription/access_overrides.dart';

class _FakeAuthRepository extends Mock implements AuthRepository {}

class _FakeNotificationsRepository extends Mock
    implements NotificationsRepository {}

class _FakePerformanceRepository extends Mock
    implements PerformanceRepository {}

class _FakeAiAnalysisRepository extends Mock implements AiAnalysisRepository {}

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

  testWidgets('App boots and shows the home screen for a signed-in user', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = _FakeAuthRepository();
    when(() => repository.restoreSession()).thenAnswer(
      (_) async => const AuthSession(
        user: AuthUser(
          id: 'user-1',
          email: 'jane@example.com',
          firstName: 'Jane',
          lastName: 'Doe',
          role: 'USER',
        ),
        accessToken: 'access-token-1',
      ),
    );
    final notificationsRepository = _FakeNotificationsRepository();
    when(() => notificationsRepository.getUnreadCount())
        .thenAnswer((_) async => const Result.success(0));
    when(() => notificationsRepository.getStudyReminders())
        .thenAnswer((_) async => const Result.success([]));
    final performanceRepository = _FakePerformanceRepository();
    when(() => performanceRepository.getOverview(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.success(_overview));
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
    final aiAnalysisRepository = _FakeAiAnalysisRepository();
    when(
      () => aiAnalysisRepository.getOverallAnalysis(
        filter: any(named: 'filter'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async => Result.success(_insufficientAnalysis));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...accessOverrides(),
          authRepositoryProvider.overrideWithValue(repository),
          notificationsRepositoryProvider.overrideWithValue(
            notificationsRepository,
          ),
          performanceRepositoryProvider.overrideWithValue(
            performanceRepository,
          ),
          aiAnalysisRepositoryProvider.overrideWithValue(aiAnalysisRepository),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MADEEN'), findsOneWidget);
    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
  });
}
