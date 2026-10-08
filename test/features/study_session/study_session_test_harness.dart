import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/study_session/data/repositories/study_session_repository_impl.dart';
import 'package:mobile/features/study_session/domain/repositories/study_session_repository.dart';
import 'package:mobile/features/study_session/presentation/screens/active_study_session_screen.dart';
import 'package:mobile/features/study_session/presentation/screens/question_review_screen.dart';
import 'package:mobile/features/study_session/presentation/screens/study_session_results_screen.dart';
import 'package:mobile/features/study_session/presentation/screens/study_session_setup_screen.dart';
import 'package:mobile/features/study_session/presentation/screens/submission_review_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

/// The Setup and Active-session screens are tall (a scrollable question
/// list, or every setup control at once) — the default 800x600 test
/// surface forces content below the fold, where a plain `ListView` (not
/// `.builder`) still only *mounts* elements near the viewport + cache
/// extent, so `find.text()` genuinely finds nothing for anything further
/// down (not just "off-screen for tap purposes"). Call this once per test
/// that needs to interact with or assert on content that might be low in
/// one of these screens, instead of fighting it with `ensureVisible`/drags.
void useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Test-only harness: a minimal GoRouter carrying exactly the Study Session
/// route chain (mirrors the paths registered in core/router/app_router.dart)
/// so screens under test can use `context.push`/`context.pop` for real,
/// without pulling in auth/curriculum routing (that's covered separately by
/// the full-App routing test).
Widget wrapStudySessionScreen({
  required StudySessionRepository repository,
  String initialLocation = '/topics/topic-1',
  String topicId = 'topic-1',
  String? topicName = 'Flexible Budget',
  Locale? locale,
}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/topics/:topicId',
        builder: (context, state) =>
            StudySessionSetupScreen(topicId: topicId, topicName: topicName),
      ),
      GoRoute(
        path: AppRoutes.studySessionActive,
        builder: (context, state) => const ActiveStudySessionScreen(),
      ),
      GoRoute(
        path: AppRoutes.studySessionSubmissionReview,
        builder: (context, state) => const SubmissionReviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.studySessionResults,
        builder: (context, state) => const StudySessionResultsScreen(),
      ),
      GoRoute(
        path: AppRoutes.studySessionReview,
        builder: (context, state) => const QuestionReviewScreen(),
      ),
      // A stand-in for where "Done" on Results sends the student (Home) —
      // Home itself isn't part of this feature's own route chain.
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) =>
            const Scaffold(body: Center(child: Text('Home'))),
      ),
    ],
  );

  return ProviderScope(
    overrides: [studySessionRepositoryProvider.overrideWithValue(repository)],
    retry: appRetryPolicy,
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}
