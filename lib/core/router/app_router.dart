import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/home_screen.dart';
import '../../features/ai_analysis/presentation/screens/ai_analysis_overview_screen.dart';
import '../../features/ai_analysis/presentation/screens/attempt_ai_insight_screen.dart';
import '../../features/ai_analysis/presentation/screens/topic_ai_insight_screen.dart';
import '../../features/ai_tutor/presentation/screens/ai_tutor_screen.dart';
import '../../features/auth/presentation/providers/auth_notifier.dart';
import '../../features/auth/presentation/providers/auth_state.dart';
import '../../features/auth/presentation/screens/change_password_screen.dart';
import '../../features/auth/presentation/screens/delete_account_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/course/presentation/screens/course_details_screen.dart';
import '../../features/course/presentation/screens/courses_screen.dart';
import '../../features/course/presentation/screens/lesson_details_screen.dart';
import '../../features/curriculum/presentation/screens/parts_screen.dart';
import '../../features/curriculum/presentation/screens/programs_screen.dart';
import '../../features/curriculum/presentation/screens/sub_units_screen.dart';
import '../../features/curriculum/presentation/screens/topics_screen.dart';
import '../../features/curriculum/presentation/screens/units_screen.dart';
import '../../features/exam_simulation/presentation/screens/active_exam_screen.dart';
import '../../features/exam_simulation/presentation/screens/exam_post_review_screen.dart';
import '../../features/exam_simulation/presentation/screens/exam_results_screen.dart';
import '../../features/exam_simulation/presentation/screens/exam_setup_screen.dart';
import '../../features/exam_simulation/presentation/screens/exam_submission_review_screen.dart';
import '../../features/exam_simulation/presentation/providers/exam_notifier.dart';
import '../../features/exam_simulation/presentation/providers/exam_state.dart';
import '../../features/notifications/presentation/screens/notification_details_page.dart';
import '../../features/notifications/presentation/screens/notification_preferences_page.dart';
import '../../features/notifications/presentation/screens/notifications_page.dart';
import '../../features/notifications/presentation/screens/study_reminder_editor_page.dart';
import '../../features/notifications/presentation/screens/study_reminders_page.dart';
import '../../features/performance/presentation/screens/attempt_details_screen.dart';
import '../../features/performance/presentation/screens/attempt_history_screen.dart';
import '../../features/performance/presentation/screens/performance_overview_screen.dart';
import '../../features/performance/presentation/screens/topic_performance_screen.dart';
import '../../features/study_session/presentation/screens/active_study_session_screen.dart';
import '../../features/subscription/presentation/screens/plans_screen.dart';
import '../../features/study_session/presentation/screens/question_review_screen.dart';
import '../../features/study_session/presentation/screens/study_session_results_screen.dart';
import '../../features/study_session/presentation/screens/study_session_setup_screen.dart';
import '../../features/study_session/presentation/screens/submission_review_screen.dart';
import 'router_refresh_notifier.dart';

/// Route paths as constants so feature code never hardcodes path strings.
/// Feature modules (study-session, simulation, course, ...) register their
/// own routes here starting later phases — see ARCHITECTURE.md §3 for the
/// module list this mirrors. This file is the app's composition point for
/// navigation, so — unlike core/network or core/error — it is expected to
/// import feature screens (§31.9).
abstract final class AppRoutes {
  static const home = '/';
  static const profile = '/profile';
  static const changePassword = '/profile/change-password';
  static const deleteAccount = '/profile/delete-account';
  static const plans = '/plans';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password';

  // Curriculum — each level's path carries the program id (whose tree,
  // loaded in one call, every level is read from) and its own parent's id;
  // display context for the AppBar travels separately via `extra`, not the
  // URL, since the parent names aren't needed to fetch anything (see
  // CurriculumAppBarTitle).
  static const curriculum = '/curriculum';
  static String curriculumParts(String programId) =>
      '/curriculum/programs/$programId/parts';
  static String curriculumUnits(String programId, String partId) =>
      '/curriculum/programs/$programId/parts/$partId/units';
  static String curriculumSubUnits(String programId, String unitId) =>
      '/curriculum/programs/$programId/units/$unitId/sub-units';
  static String curriculumTopics(String programId, String subUnitId) =>
      '/curriculum/programs/$programId/sub-units/$subUnitId/topics';
  static String curriculumTopicDetail(String topicId) =>
      '/curriculum/topics/$topicId';

  // Study Session / Question Bank (Phase 4). Reached from a Topic
  // (curriculumTopicDetail) and, aside from Setup, driven entirely by
  // studySessionNotifierProvider rather than by path parameters — there is
  // exactly one in-progress session at a time, so these are wizard steps,
  // not independently deep-linkable resources. Exam Simulation (a separate,
  // later feature) gets its own route namespace — nothing here is reused
  // for it.
  static const studySessionActive = '/study-session/active';
  static const studySessionSubmissionReview =
      '/study-session/submission-review';
  static const studySessionResults = '/study-session/results';
  static const studySessionReview = '/study-session/review';

  // Exam Simulation (Phase 5). Reached from Home, not from Curriculum — an
  // exam is scoped to a Program + Part the student picks on the Setup
  // screen itself, not a Topic. Same "wizard steps driven by
  // examNotifierProvider, not path parameters" reasoning as Study Session.
  // A completely separate route namespace on purpose — see this feature's
  // README on why it must never share Study Session's routes or state.
  static const examSetup = '/exam-simulation';
  static const examActive = '/exam-simulation/active';
  static const examSubmissionReview = '/exam-simulation/submission-review';
  static const examResults = '/exam-simulation/results';
  static const examPostReview = '/exam-simulation/post-review';

  /// Post-exam review opened on one view (`all` / `wrong` / `unanswered`)
  /// and scrolled to one question — query parameters on the same route.
  static String examPostReviewAt({required String show, String? questionId}) =>
      Uri(
        path: examPostReview,
        queryParameters: {'show': show, 'q': ?questionId},
      ).toString();

  // Performance Analytics (Phase 6). Reached from Home — an independent,
  // read-only feature over Study Session/Exam Simulation results (see
  // features/performance/README.md), so unlike those two this is plain
  // deep-linkable resources (an attempt id in the path), not wizard steps
  // driven by a single in-flight notifier.
  static const performanceOverview = '/performance';
  static const performanceTopics = '/performance/topics';
  static const performanceAttempts = '/performance/attempts';
  static String performanceAttemptDetail(String attemptId) =>
      '/performance/attempts/$attemptId';

  // AI-Powered Performance Analysis (Phase 7) — an explanatory/
  // recommendation layer over Performance Analytics (see
  // features/ai_analysis/README.md): never a source of truth for any
  // number, only an interpretation of numbers Performance already fetched.
  // Reached from Performance Overview, and contextually from a topic
  // (Topic Performance) or an attempt (Attempt Details).
  static const aiAnalysisOverview = '/performance/ai-analysis';
  static String aiAnalysisTopic(String topicId) =>
      '/performance/ai-analysis/topics/$topicId';
  static String aiAnalysisAttempt(String attemptId) =>
      '/performance/ai-analysis/attempts/$attemptId';

  // Notifications & Study Reminders (Phase 8). Reached from Home (bell icon)
  // and Profile (Notification Settings / Study Reminders entries) — a
  // read/write feature over its own domain, independent of every other
  // feature module the way Performance is (see features/notifications/
  // README). Settings routes sit under `/settings/*` since Notification
  // Preferences and Study Reminders are configuration, not content.
  static const notifications = '/notifications';
  static String notificationDetail(String notificationId) =>
      '/notifications/$notificationId';
  static const notificationPreferences = '/settings/notifications';
  static const studyReminders = '/settings/study-reminders';
  static const studyReminderNew = '/settings/study-reminders/new';
  static String studyReminderEdit(String reminderId) =>
      '/settings/study-reminders/$reminderId';

  // AI Tutor (Phase 10) — mock-backed conversational study help, reached
  // from Home. Deliberately checked against `examNotifierProvider` in this
  // router's own `redirect` below, not inside ExamNotifier itself — per
  // ARCHITECTURE.md §17.1, AI Tutor must never be reachable during a live
  // Exam Simulation attempt, and the redirect is this app's single
  // existing enforcement point for "which routes are reachable right now"
  // (the same mechanism auth already uses), so this reuses it rather than
  // adding a second guarding mechanism.
  static const aiTutor = '/ai-tutor';

  // Course (Phase 11) — mock-backed "record once, serve many" video
  // courses (ARCHITECTURE.md §13), reached from Home. No access-control
  // route guard exists for this, deliberately: Entitlement (the thing
  // that would decide who can see a course) is not implemented anywhere
  // in this project — see Course's own doc comment — so every
  // authenticated user can browse every listed course, same as every
  // other mock-backed feature today.
  static const courses = '/courses';
  static String courseDetail(String courseId) => '/courses/$courseId';
  static String lessonDetail(String courseId, String lessonId) =>
      '/courses/$courseId/lessons/$lessonId';

  static const _publicRoutes = {login, register, forgotPassword, resetPassword};
  static bool isPublic(String path) => _publicRoutes.contains(path);
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = RouterRefreshNotifier();
  ref.listen(authNotifierProvider, (_, _) => refreshNotifier.notify());
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authNotifierProvider);
      final isPublicRoute = AppRoutes.isPublic(state.matchedLocation);

      // Initializing is handled before the router ever mounts (see
      // app/app.dart) — by the time redirect runs, auth state is settled.
      if (authState is AuthUnauthenticated) {
        return isPublicRoute ? null : AppRoutes.login;
      }
      if (authState is AuthAuthenticated && isPublicRoute) {
        return AppRoutes.home;
      }

      // AI Tutor must never be reachable while an Exam Simulation attempt
      // is in progress — see AppRoutes.aiTutor's own doc comment. Checked
      // here (not inside ExamNotifier) so it's enforced for every path
      // into the route (Home's entry card, a future deep link, browser
      // back/forward on web, ...), not just the one UI affordance that
      // happens to call context.push today.
      if (state.matchedLocation == AppRoutes.aiTutor) {
        final examState = ref.read(examNotifierProvider);
        final examInProgress =
            examState is ExamActive ||
            examState is ExamTimedOut ||
            examState is ExamSubmitting;
        if (examInProgress) return AppRoutes.examActive;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.changePassword,
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.deleteAccount,
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: AppRoutes.plans,
        builder: (context, state) => const PlansScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => ResetPasswordScreen(
          initialToken: state.uri.queryParameters['token'],
        ),
      ),
      GoRoute(
        path: AppRoutes.curriculum,
        builder: (context, state) => const ProgramsScreen(),
      ),
      GoRoute(
        path: '/curriculum/programs/:programId/parts',
        builder: (context, state) => PartsScreen(
          programId: state.pathParameters['programId']!,
          programName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/curriculum/programs/:programId/parts/:partId/units',
        builder: (context, state) => UnitsScreen(
          programId: state.pathParameters['programId']!,
          partId: state.pathParameters['partId']!,
          partName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/curriculum/programs/:programId/units/:unitId/sub-units',
        builder: (context, state) => SubUnitsScreen(
          programId: state.pathParameters['programId']!,
          unitId: state.pathParameters['unitId']!,
          unitName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/curriculum/programs/:programId/sub-units/:subUnitId/topics',
        builder: (context, state) => TopicsScreen(
          programId: state.pathParameters['programId']!,
          subUnitId: state.pathParameters['subUnitId']!,
          subUnitName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/curriculum/topics/:topicId',
        builder: (context, state) => StudySessionSetupScreen(
          topicId: state.pathParameters['topicId']!,
          topicName: state.extra as String?,
        ),
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
      GoRoute(
        path: AppRoutes.performanceOverview,
        builder: (context, state) => const PerformanceOverviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.performanceTopics,
        builder: (context, state) => const TopicPerformanceScreen(),
      ),
      GoRoute(
        path: AppRoutes.performanceAttempts,
        builder: (context, state) => const AttemptHistoryScreen(),
      ),
      GoRoute(
        path: '/performance/attempts/:attemptId',
        builder: (context, state) =>
            AttemptDetailsScreen(attemptId: state.pathParameters['attemptId']!),
      ),
      GoRoute(
        path: AppRoutes.aiAnalysisOverview,
        builder: (context, state) => const AiAnalysisOverviewScreen(),
      ),
      GoRoute(
        path: '/performance/ai-analysis/topics/:topicId',
        builder: (context, state) => TopicAiInsightScreen(
          topicId: state.pathParameters['topicId']!,
          topicName: state.extra as String?,
        ),
      ),
      GoRoute(
        path: '/performance/ai-analysis/attempts/:attemptId',
        builder: (context, state) => AttemptAiInsightScreen(
          attemptId: state.pathParameters['attemptId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (context, state) => const NotificationsPage(),
      ),
      GoRoute(
        path: '/notifications/:notificationId',
        builder: (context, state) => NotificationDetailsPage(
          notificationId: state.pathParameters['notificationId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.notificationPreferences,
        builder: (context, state) => const NotificationPreferencesPage(),
      ),
      GoRoute(
        path: AppRoutes.studyReminders,
        builder: (context, state) => const StudyRemindersPage(),
      ),
      GoRoute(
        path: AppRoutes.studyReminderNew,
        builder: (context, state) => const StudyReminderEditorPage(),
      ),
      GoRoute(
        path: '/settings/study-reminders/:reminderId',
        builder: (context, state) => StudyReminderEditorPage(
          reminderId: state.pathParameters['reminderId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.aiTutor,
        builder: (context, state) => const AiTutorScreen(),
      ),
      GoRoute(
        path: AppRoutes.courses,
        builder: (context, state) => const CoursesScreen(),
      ),
      GoRoute(
        path: '/courses/:courseId',
        builder: (context, state) =>
            CourseDetailsScreen(courseId: state.pathParameters['courseId']!),
      ),
      GoRoute(
        path: '/courses/:courseId/lessons/:lessonId',
        builder: (context, state) => LessonDetailsScreen(
          courseId: state.pathParameters['courseId']!,
          lessonId: state.pathParameters['lessonId']!,
        ),
      ),
    ],
  );
});
