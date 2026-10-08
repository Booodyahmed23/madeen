import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/ai_analysis/presentation/screens/ai_analysis_overview_screen.dart';
import 'package:mobile/features/ai_analysis/presentation/screens/attempt_ai_insight_screen.dart';
import 'package:mobile/features/ai_analysis/presentation/screens/topic_ai_insight_screen.dart';
import 'package:mobile/features/ai_tutor/presentation/screens/ai_tutor_screen.dart';
import 'package:mobile/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:mobile/features/auth/presentation/screens/register_screen.dart';
import 'package:mobile/features/auth/presentation/screens/reset_password_screen.dart';
import 'package:mobile/features/course/presentation/screens/course_details_screen.dart';
import 'package:mobile/features/course/presentation/screens/courses_screen.dart';
import 'package:mobile/features/course/presentation/screens/lesson_details_screen.dart';
import 'package:mobile/features/curriculum/presentation/screens/programs_screen.dart';
import 'package:mobile/features/exam_simulation/presentation/screens/exam_setup_screen.dart';
import 'package:mobile/features/notifications/presentation/screens/notification_details_page.dart';
import 'package:mobile/features/notifications/presentation/screens/notification_preferences_page.dart';
import 'package:mobile/features/notifications/presentation/screens/notifications_page.dart';
import 'package:mobile/features/notifications/presentation/screens/study_reminder_editor_page.dart';
import 'package:mobile/features/notifications/presentation/screens/study_reminders_page.dart';
import 'package:mobile/features/performance/presentation/screens/attempt_details_screen.dart';
import 'package:mobile/features/performance/presentation/screens/attempt_history_screen.dart';
import 'package:mobile/features/performance/presentation/screens/performance_overview_screen.dart';
import 'package:mobile/features/performance/presentation/screens/topic_performance_screen.dart';
import 'package:mobile/features/study_session/presentation/screens/study_session_setup_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phase 15 QA: every major screen, rendered with its default (mock-backed)
/// data at the smallest supported phone width with enlarged text, in both
/// languages and both themes, must lay out without overflow or other
/// framework errors. Screens are scrolled through so content below the
/// fold is built too.
final _screens = <String, Widget Function()>{
  'Login': () => const LoginScreen(),
  'Register': () => const RegisterScreen(),
  'Forgot password': () => const ForgotPasswordScreen(),
  'Reset password': () => const ResetPasswordScreen(),
  'Programs': () => const ProgramsScreen(),
  'Study session setup': () => const StudySessionSetupScreen(
    topicId: 'topic-variance-analysis',
    topicName: 'Variance Analysis',
  ),
  'Exam setup': () => const ExamSetupScreen(),
  'Performance overview': () => const PerformanceOverviewScreen(),
  'Attempt history': () => const AttemptHistoryScreen(),
  'Attempt details': () =>
      const AttemptDetailsScreen(attemptId: 'perf-attempt-1'),
  'Topic performance': () => const TopicPerformanceScreen(),
  'AI analysis': () => const AiAnalysisOverviewScreen(),
  'Topic AI insight': () => const TopicAiInsightScreen(
    topicId: 'topic-budgeting',
    topicName: 'Budgeting',
  ),
  'Attempt AI insight': () =>
      const AttemptAiInsightScreen(attemptId: 'perf-attempt-1'),
  'AI tutor': () => const AiTutorScreen(),
  'Courses': () => const CoursesScreen(),
  'Course details': () =>
      const CourseDetailsScreen(courseId: 'course-cma-part-1'),
  'Lesson details': () => const LessonDetailsScreen(
    courseId: 'course-cma-part-1',
    lessonId: 'lesson-intro-budgeting',
  ),
  'Notifications': () => const NotificationsPage(),
  'Notification details': () =>
      const NotificationDetailsPage(notificationId: 'notif-3'),
  'Notification preferences': () => const NotificationPreferencesPage(),
  'Study reminders': () => const StudyRemindersPage(),
  'Study reminder editor': () => const StudyReminderEditorPage(),
};

Future<List<String>> _render(
  WidgetTester tester,
  Widget screen, {
  required Locale locale,
  required ThemeMode themeMode,
  required double textScale,
}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    // The error plus the widget that caused it, e.g. "…overflowed by 12
    // pixels on the right. (lib/…/foo.dart:42)".
    final source = RegExp(r'lib/[\w/]+\.dart:\d+')
        .firstMatch(details.toString())
        ?.group(0);
    errors.add(
      '${details.exceptionAsString().split('\n').first}'
      '${source == null ? '' : ' ($source)'}',
    );
  };

  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;

  try {
    await tester.pumpWidget(
      ProviderScope(
        retry: appRetryPolicy,
        child: MaterialApp(
          theme: AppTheme.madeenLight,
          darkTheme: AppTheme.madeenDark,
          builder: AppTheme.localeAwareBuilder,
          themeMode: themeMode,
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Walk the main scrollable down so lazily-built content is laid out.
    // The page's vertical scroll view — not e.g. a text field's own
    // internal Scrollable.
    final scrollables = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .hitTestable();
    // After a layout error some boxes are never laid out, so only scroll
    // a cleanly laid-out page; otherwise report what already failed.
    if (errors.isEmpty && scrollables.evaluate().isNotEmpty) {
      for (var i = 0; i < 6; i++) {
        await tester.drag(
          scrollables.first,
          const Offset(0, -400),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
      }
    }
  } finally {
    FlutterError.onError = previous;
    // Unmount inside the test so pending timers/streams don't leak.
    await tester.pumpWidget(const SizedBox());
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  }
  return errors;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // 175% is the largest scale every screen supports at 320pt today. At
  // 200%, Attempt History / Topic Performance (fixed header above an
  // Expanded list), AI Tutor and the reminder editor's time row still
  // overflow — tracked in the Phase 15 audit, not silently excluded.
  const variants = [
    (Locale('en'), ThemeMode.light, 1.3),
    (Locale('ar'), ThemeMode.dark, 1.3),
    (Locale('en'), ThemeMode.dark, 1.75),
    (Locale('ar'), ThemeMode.light, 1.75),
  ];

  for (final MapEntry(key: name, value: build) in _screens.entries) {
    for (final (locale, themeMode, textScale) in variants) {
      testWidgets('$name — ${locale.languageCode}, ${themeMode.name}, '
          '320pt, ${(textScale * 100).round()}% text', (tester) async {
        final errors = await _render(
          tester,
          build(),
          locale: locale,
          themeMode: themeMode,
          textScale: textScale,
        );
        expect(errors, isEmpty);
      });
    }
  }
}
