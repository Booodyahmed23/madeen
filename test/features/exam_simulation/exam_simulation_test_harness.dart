import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/curriculum/data/repositories/curriculum_repository_impl.dart';
import 'package:mobile/features/curriculum/domain/repositories/curriculum_repository.dart';
import 'package:mobile/features/exam_simulation/data/repositories/exam_repository_impl.dart';
import 'package:mobile/features/exam_simulation/domain/repositories/exam_repository.dart';
import 'package:mobile/features/exam_simulation/presentation/screens/active_exam_screen.dart';
import 'package:mobile/features/exam_simulation/presentation/screens/exam_post_review_screen.dart';
import 'package:mobile/features/exam_simulation/presentation/screens/exam_results_screen.dart';
import 'package:mobile/features/exam_simulation/presentation/screens/exam_setup_screen.dart';
import 'package:mobile/features/exam_simulation/presentation/screens/exam_submission_review_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

import '../subscription/access_overrides.dart';

/// The Setup and Active-exam screens are tall — a plain (non-`.builder`)
/// `ListView` only *mounts* elements near the viewport + cache extent, so
/// `find.text()` genuinely finds nothing for content pushed below the fold
/// at the default 800x600 test surface (this is the same lesson learned
/// building Study Session's tests — see that feature's test harness).
/// Call this once per test that interacts with such content.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Test-only harness: a minimal GoRouter carrying exactly the Exam
/// Simulation route chain (mirrors core/router/app_router.dart) plus a
/// stand-in Setup entry route, so screens under test can use
/// `context.push`/`context.pop` for real.
Widget wrapExamScreen({
  required ExamRepository examRepository,
  required CurriculumRepository curriculumRepository,
  String initialLocation = AppRoutes.examSetup,
  Locale? locale,
  ThemeMode? themeMode,
}) {
  // The real app's MADEEN themes, only when a test asks for a specific
  // locale/theme (layout checks) — every other test keeps the plain app.
  final styled = locale != null || themeMode != null;
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.examSetup,
        builder: (context, state) => const ExamSetupScreen(),
      ),
      GoRoute(
        path: AppRoutes.examActive,
        builder: (context, state) => const ActiveExamScreen(),
      ),
      GoRoute(
        path: AppRoutes.examSubmissionReview,
        builder: (context, state) => const ExamSubmissionReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.examResults,
        builder: (context, state) => const ExamResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.examPostReview,
        builder: (context, state) => ExamPostReviewScreen(
          initialView: ExamReviewView.fromQuery(
            state.uri.queryParameters['show'],
          ),
          focusQuestionId: state.uri.queryParameters['q'],
        ),
      ),
      // A stand-in for wherever Results' "Done" sends the student back to.
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      ...accessOverrides(),
      examRepositoryProvider.overrideWithValue(examRepository),
      curriculumRepositoryProvider.overrideWithValue(curriculumRepository),
    ],
    retry: appRetryPolicy,
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      theme: styled ? AppTheme.madeenLight : null,
      darkTheme: styled ? AppTheme.madeenDark : null,
      themeMode: themeMode ?? ThemeMode.system,
      builder: styled ? AppTheme.localeAwareBuilder : null,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}
