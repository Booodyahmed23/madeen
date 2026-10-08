import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/app/home_screen.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/core/theme/madeen_tokens.dart';
import 'package:mobile/core/theme/madeen_typography.dart';
import 'package:mobile/features/ai_analysis/data/repositories/ai_analysis_repository_impl.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_metadata.dart';
import 'package:mobile/features/ai_analysis/domain/entities/ai_analysis_scope.dart';
import 'package:mobile/features/ai_analysis/domain/repositories/ai_analysis_repository.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mobile/features/performance/data/repositories/performance_repository_impl.dart';
import 'package:mobile/features/performance/domain/entities/attempt_history_page.dart';
import 'package:mobile/features/performance/domain/entities/attempt_summary.dart';
import 'package:mobile/features/performance/domain/entities/attempt_type.dart';
import 'package:mobile/features/performance/domain/entities/performance_filter.dart';
import 'package:mobile/features/performance/domain/entities/performance_overview.dart';
import 'package:mobile/features/performance/domain/repositories/performance_repository.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

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
  totalAttempts: 4,
  questionsPracticed: 40,
  totalAnswered: 40,
  totalCorrect: 36,
  overallScorePercent: 90.0,
  totalTime: Duration(seconds: 1200),
  averageTimePerQuestion: Duration(seconds: 30),
);

final _attempt = AttemptSummary(
  attemptId: 'perf-attempt-1',
  type: AttemptType.studySession,
  completedAt: DateTime(2026, 9, 16, 9),
  contentLabel: 'Budgeting',
  totalQuestions: 20,
  answered: 20,
  correct: 18,
  scorePercent: 90.0,
  duration: const Duration(seconds: 1200),
);

final _readyAnalysis = AiAnalysis(
  metadata: AiAnalysisMetadata(
    scope: AiAnalysisScope.overall,
    status: AiAnalysisStatus.ready,
    generatedAt: DateTime(2026, 9, 16, 9),
    basedOnAttemptCount: 4,
  ),
  overallSummary: 'Your recent practice shows strong performance overall.',
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

final _reminder = StudyReminder(
  id: 'reminder-1',
  title: 'Daily CMA Practice',
  enabled: true,
  hour: 7,
  minute: 30,
  repeat: ReminderRepeat.everyDay,
  createdAt: DateTime(2026, 9, 1, 7, 30),
);

/// Home is wrapped in its own tiny [GoRouter] — every destination route it
/// can push to is stubbed to a bare, uniquely-labeled `Scaffold`, so this
/// suite tests Home's own composition and navigation *intent* without
/// pulling in every other feature's real screen (those are exercised by
/// their own router tests, e.g. `test/core/router/*_routes_test.dart`).
Widget _wrap({
  required AuthRepository authRepository,
  required NotificationsRepository notificationsRepository,
  required PerformanceRepository performanceRepository,
  required AiAnalysisRepository aiAnalysisRepository,
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  final router = GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.curriculum,
        builder: (context, state) =>
            const Scaffold(body: Text('Curriculum Screen')),
      ),
      GoRoute(
        path: AppRoutes.examSetup,
        builder: (context, state) =>
            const Scaffold(body: Text('Exam Setup Screen')),
      ),
      GoRoute(
        path: AppRoutes.performanceOverview,
        builder: (context, state) =>
            const Scaffold(body: Text('Performance Overview Screen')),
      ),
      GoRoute(
        path: AppRoutes.aiAnalysisOverview,
        builder: (context, state) =>
            const Scaffold(body: Text('AI Analysis Overview Screen')),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) =>
            const Scaffold(body: Text('Notifications Screen')),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) =>
            const Scaffold(body: Text('Profile Screen')),
      ),
      GoRoute(
        path: AppRoutes.studyReminders,
        builder: (context, state) =>
            const Scaffold(body: Text('Study Reminders Screen')),
      ),
      GoRoute(
        path: AppRoutes.courses,
        builder: (context, state) =>
            const Scaffold(body: Text('Courses Screen')),
      ),
      GoRoute(
        path: '/performance/attempts/:attemptId',
        builder: (context, state) => Scaffold(
          body: Text('Attempt Detail ${state.pathParameters['attemptId']}'),
        ),
      ),
    ],
  );

  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepository),
      notificationsRepositoryProvider.overrideWithValue(
        notificationsRepository,
      ),
      performanceRepositoryProvider.overrideWithValue(performanceRepository),
      aiAnalysisRepositoryProvider.overrideWithValue(aiAnalysisRepository),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      // The app's real themes, exactly as app/app.dart applies them.
      theme: AppTheme.madeenLight,
      darkTheme: AppTheme.madeenDark,
      builder: AppTheme.localeAwareBuilder,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

/// A ready-to-pump set of mocks with sensible, deterministic defaults for
/// every provider Home reads — individual tests override just the one
/// repository/method whose state they're exercising.
class _Mocks {
  _Mocks()
    : auth = MockAuthRepository(),
      notifications = MockNotificationsRepository(),
      performance = MockPerformanceRepository(),
      aiAnalysis = MockAiAnalysisRepository() {
    when(() => auth.restoreSession()).thenAnswer((_) async => _session);
    when(() => notifications.getUnreadCount())
        .thenAnswer((_) async => const Result.success(0));
    when(() => notifications.getStudyReminders())
        .thenAnswer((_) async => const Result.success([]));
    when(() => performance.getOverview(filter: any(named: 'filter')))
        .thenAnswer((_) async => const Result.success(_overview));
    when(
      () => performance.getAttempts(
        filter: any(named: 'filter'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer(
      (_) async =>
          const Result.success(AttemptHistoryPage(items: [], hasMore: false)),
    );
    when(
      () => aiAnalysis.getOverallAnalysis(
        filter: any(named: 'filter'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async => Result.success(_insufficientAnalysis));
  }

  final MockAuthRepository auth;
  final MockNotificationsRepository notifications;
  final MockPerformanceRepository performance;
  final MockAiAnalysisRepository aiAnalysis;

  Widget wrap({Locale locale = const Locale('en'), ThemeMode? themeMode}) =>
      _wrap(
        authRepository: auth,
        notificationsRepository: notifications,
        performanceRepository: performance,
        aiAnalysisRepository: aiAnalysis,
        locale: locale,
        themeMode: themeMode ?? ThemeMode.light,
      );
}

// Phase 14A (MADEEN design): section headers render as upper-case
// eyebrows (MadeenSectionHeader), so title assertions use upper case.
void main() {
  setUpAll(() {
    registerFallbackValue(const PerformanceFilter());
  });

  Future<void> pumpTall(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(800, 2800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  group('rendering', () {
    testWidgets('1. authenticated Home renders the dashboard', (tester) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      expect(find.text('PERFORMANCE SNAPSHOT'), findsOneWidget);
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);
      expect(find.text('UPCOMING STUDY REMINDER'), findsOneWidget);
      expect(find.text('Curriculum'), findsOneWidget);
      expect(find.text('Exam Simulation'), findsOneWidget);
    });

    testWidgets('2. greeting renders the authenticated user\'s name', (
      tester,
    ) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      expect(find.textContaining('Jane'), findsOneWidget);
    });
  });

  group('navigation', () {
    testWidgets('3. Start Studying navigates to Curriculum', (tester) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      await tester.tap(find.widgetWithText(FilledButton, 'Start Studying'));
      await tester.pumpAndSettle();

      expect(find.text('Curriculum Screen'), findsOneWidget);
    });

    testWidgets('16. Exam Simulation card navigates to Exam Setup', (
      tester,
    ) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      await tester.tap(find.text('Exam Simulation'));
      await tester.pumpAndSettle();

      expect(find.text('Exam Setup Screen'), findsOneWidget);
    });

    testWidgets('17. Curriculum card navigates to Curriculum', (tester) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      await tester.tap(find.text('Curriculum'));
      await tester.pumpAndSettle();

      expect(find.text('Curriculum Screen'), findsOneWidget);
    });

    testWidgets('Courses card navigates to Courses', (tester) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      await tester.tap(find.text('Courses'));
      await tester.pumpAndSettle();

      expect(find.text('Courses Screen'), findsOneWidget);
    });

    testWidgets('Performance Snapshot navigates to Performance Overview', (
      tester,
    ) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      await tester.tap(find.text('See Performance'));
      await tester.pumpAndSettle();

      expect(find.text('Performance Overview Screen'), findsOneWidget);
    });

    testWidgets('AI Analysis teaser navigates to AI Analysis Overview', (
      tester,
    ) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      await tester.tap(find.text('AI ANALYSIS'));
      await tester.pumpAndSettle();

      expect(find.text('AI Analysis Overview Screen'), findsOneWidget);
    });

    testWidgets('a recent attempt navigates to its Attempt Detail', (
      tester,
    ) async {
      final mocks = _Mocks();
      when(
        () => mocks.performance.getAttempts(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          AttemptHistoryPage(items: [_attempt], hasMore: false),
        ),
      );
      await pumpTall(tester, mocks.wrap());

      await tester.tap(find.text('Budgeting'));
      await tester.pumpAndSettle();

      expect(find.text('Attempt Detail perf-attempt-1'), findsOneWidget);
    });
  });

  group('Performance Snapshot states', () {
    testWidgets('4. loading', (tester) async {
      final mocks = _Mocks();
      final completer = Completer<Result<PerformanceOverview>>();
      when(() => mocks.performance.getOverview(filter: any(named: 'filter')))
          .thenAnswer((_) => completer.future);

      tester.view.physicalSize = const Size(800, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(mocks.wrap());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      completer.complete(const Result.success(_overview));
      await tester.pumpAndSettle();
    });

    testWidgets('5. loaded', (tester) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      expect(find.text('90%'), findsWidgets); // accuracy and score both 90%
      expect(find.text('40'), findsOneWidget); // questions practiced
      expect(find.text('4'), findsOneWidget); // total attempts
    });

    testWidgets('6. error', (tester) async {
      final mocks = _Mocks();
      when(() => mocks.performance.getOverview(filter: any(named: 'filter')))
          .thenAnswer((_) async => const Result.failure(NetworkFailure()));
      await pumpTall(tester, mocks.wrap());

      expect(find.text('Unable to load performance data.'), findsOneWidget);
    });

    testWidgets('7. retry re-fetches after a failure', (tester) async {
      final mocks = _Mocks();
      var callCount = 0;
      when(() => mocks.performance.getOverview(filter: any(named: 'filter')))
          .thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return const Result.failure(NetworkFailure());
            return const Result.success(_overview);
          });
      await pumpTall(tester, mocks.wrap());

      expect(find.text('Unable to load performance data.'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Retry').first);
      await tester.pumpAndSettle();

      expect(find.text('90%'), findsWidgets);
      expect(callCount, 2);
    });
  });

  group('Recent Activity states', () {
    testWidgets('8. loading', (tester) async {
      final mocks = _Mocks();
      final completer = Completer<Result<AttemptHistoryPage>>();
      when(
        () => mocks.performance.getAttempts(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => completer.future);

      tester.view.physicalSize = const Size(800, 2800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(mocks.wrap());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      completer.complete(
        const Result.success(AttemptHistoryPage(items: [], hasMore: false)),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('9. populated', (tester) async {
      final mocks = _Mocks();
      when(
        () => mocks.performance.getAttempts(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          AttemptHistoryPage(items: [_attempt], hasMore: false),
        ),
      );
      await pumpTall(tester, mocks.wrap());

      expect(find.text('Budgeting'), findsOneWidget);
    });

    testWidgets('10. empty', (tester) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      expect(
        find.text(
          'No recent activity yet — complete a study session or exam '
          'simulation to see it here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('11. error', (tester) async {
      final mocks = _Mocks();
      when(
        () => mocks.performance.getAttempts(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => const Result.failure(NetworkFailure()));
      await pumpTall(tester, mocks.wrap());

      expect(find.text('Unable to load performance data.'), findsWidgets);
    });
  });

  group('AI Analysis teaser states', () {
    testWidgets('12. ready analysis shows its own summary', (tester) async {
      final mocks = _Mocks();
      when(
        () => mocks.aiAnalysis.getOverallAnalysis(
          filter: any(named: 'filter'),
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_readyAnalysis));
      await pumpTall(tester, mocks.wrap());

      expect(
        find.text('Your recent practice shows strong performance overall.'),
        findsOneWidget,
      );
    });

    testWidgets('13. insufficientData shows its own honest summary', (
      tester,
    ) async {
      final mocks = _Mocks(); // defaults to _insufficientAnalysis
      await pumpTall(tester, mocks.wrap());

      expect(
        find.text('Complete a Study Session to unlock personalized insights.'),
        findsOneWidget,
      );
    });
  });

  group('Upcoming Reminder states', () {
    testWidgets('14. populated shows the reminder title', (tester) async {
      final mocks = _Mocks();
      when(() => mocks.notifications.getStudyReminders())
          .thenAnswer((_) async => Result.success([_reminder]));
      await pumpTall(tester, mocks.wrap());

      expect(find.text('Daily CMA Practice'), findsOneWidget);
    });

    testWidgets('15. empty shows the no-reminder message and manage CTA', (
      tester,
    ) async {
      final mocks = _Mocks();
      await pumpTall(tester, mocks.wrap());

      expect(find.text('No upcoming study reminder'), findsOneWidget);
      expect(find.text('Manage reminders'), findsOneWidget);

      await tester.tap(find.text('Manage reminders'));
      await tester.pumpAndSettle();
      expect(find.text('Study Reminders Screen'), findsOneWidget);
    });
  });

  testWidgets('18. unread notification badge reflects the repository count', (
    tester,
  ) async {
    final mocks = _Mocks();
    when(() => mocks.notifications.getUnreadCount())
        .thenAnswer((_) async => const Result.success(3));
    await pumpTall(tester, mocks.wrap());

    expect(find.text('3'), findsOneWidget);
  });

  testWidgets(
    '19. the notification bell and primary CTA expose accessible semantics',
    (tester) async {
      final mocks = _Mocks();
      when(() => mocks.notifications.getUnreadCount())
          .thenAnswer((_) async => const Result.success(2));
      await pumpTall(tester, mocks.wrap());

      final bellSemantics = tester.getSemantics(
        find.byIcon(Icons.notifications_outlined),
      );
      expect(bellSemantics.label, contains('2'));

      final ctaSemantics = tester.getSemantics(find.text('Start Studying'));
      expect(ctaSemantics.label, isNotEmpty);
    },
  );

  testWidgets('20. renders in Arabic (RTL) without crashing', (tester) async {
    final mocks = _Mocks();
    await pumpTall(tester, mocks.wrap(locale: const Locale('ar')));

    expect(find.text('مرحبًا بعودتك، Jane'), findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('21. renders in dark mode without crashing', (tester) async {
    final mocks = _Mocks();
    await pumpTall(tester, mocks.wrap(themeMode: ThemeMode.dark));

    expect(find.text('PERFORMANCE SNAPSHOT'), findsOneWidget);
    final context = tester.element(find.byType(HomeScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  group('MADEEN design (Phase 14A)', () {
    /// Fills every section with real content (attempts, a reminder, a
    /// ready AI summary) so layout is exercised, not just empty states.
    _Mocks populated() {
      final mocks = _Mocks();
      when(
        () => mocks.performance.getAttempts(
          filter: any(named: 'filter'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer(
        (_) async => Result.success(
          AttemptHistoryPage(
            items: [_attempt, _attempt, _attempt],
            hasMore: false,
          ),
        ),
      );
      when(() => mocks.notifications.getStudyReminders())
          .thenAnswer((_) async => Result.success([_reminder]));
      when(
        () => mocks.aiAnalysis.getOverallAnalysis(
          filter: any(named: 'filter'),
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => Result.success(_readyAnalysis));
      return mocks;
    }

    /// Pumps Home on a small phone (iPhone SE 1st gen: 320x568pt) at 130%
    /// text scale, then scrolls through the whole page — any overflow or
    /// layout error surfaces as a test exception along the way.
    Future<void> expectNoLayoutErrorsOnSmallPhone(
      WidgetTester tester,
      Widget widget,
    ) async {
      tester.view.physicalSize = const Size(640, 1136);
      tester.view.devicePixelRatio = 2.0;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var i = 0; i < 12; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -250));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'after scroll $i');
      }
      expect(find.text('English'), findsOneWidget, reason: 'reached bottom');
    }

    testWidgets('Home renders under the MADEEN theme and fonts', (
      tester,
    ) async {
      await pumpTall(tester, populated().wrap());

      final context = tester.element(find.text('PERFORMANCE SNAPSHOT'));
      expect(MadeenTokens.of(context), MadeenTokens.light);
      expect(
        Theme.of(context).textTheme.bodyMedium?.fontFamily,
        MadeenType.sans,
      );
      final greeting = tester.widget<Text>(find.text('Welcome back, Jane'));
      expect(greeting.style?.fontFamily, MadeenType.serif);
    });

    testWidgets('dark mode uses the dedicated dark tokens, not an inversion', (
      tester,
    ) async {
      await pumpTall(tester, populated().wrap(themeMode: ThemeMode.dark));

      final context = tester.element(find.text('PERFORMANCE SNAPSHOT'));
      expect(MadeenTokens.of(context), MadeenTokens.dark);
    });

    testWidgets('no overflow on a small phone at 130% text — English', (
      tester,
    ) async {
      await expectNoLayoutErrorsOnSmallPhone(tester, populated().wrap());
    });

    testWidgets('no overflow on a small phone at 130% text — Arabic RTL', (
      tester,
    ) async {
      await expectNoLayoutErrorsOnSmallPhone(
        tester,
        populated().wrap(locale: const Locale('ar')),
      );
    });

    testWidgets('no overflow on a small phone at 130% text — dark mode', (
      tester,
    ) async {
      await expectNoLayoutErrorsOnSmallPhone(
        tester,
        populated().wrap(themeMode: ThemeMode.dark),
      );
    });

    testWidgets('Arabic eyebrows drop letter-spacing (connected script)', (
      tester,
    ) async {
      await pumpTall(tester, populated().wrap(locale: const Locale('ar')));

      final context = tester.element(find.byType(HomeScreen));
      expect(MadeenType.eyebrow(context).letterSpacing, 0);
    });

    testWidgets('Latin eyebrows keep their tracked caps', (tester) async {
      await pumpTall(tester, populated().wrap());

      final context = tester.element(find.byType(HomeScreen));
      expect(MadeenType.eyebrow(context).letterSpacing, greaterThan(0));
    });

    testWidgets('Recent Activity rows keep their content and navigate', (
      tester,
    ) async {
      await pumpTall(tester, populated().wrap());

      expect(find.text('90%'), findsWidgets);
      await tester.tap(find.text('Budgeting').first);
      await tester.pumpAndSettle();
      expect(find.text('Attempt Detail perf-attempt-1'), findsOneWidget);
    });
  });
}
