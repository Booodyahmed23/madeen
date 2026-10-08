import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/localization/locale_provider.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/core/theme/madeen_tokens.dart';
import 'package:mobile/core/theme/theme_mode_provider.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mocktail/mocktail.dart';

import '../features/subscription/access_overrides.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _user = AuthUser(
  id: 'user-sweep',
  email: 'sweep@example.com',
  firstName: 'Sweep',
  lastName: 'Tester',
  role: 'USER',
);

/// Every screen the app can show, by route — the authenticated ones on the
/// app's real sample-data sources (ids taken from those mock data sources).
/// The wizard routes (study/exam active, results, review) are visited cold,
/// with no session in progress, so their "nothing here" fallbacks render.
final _authenticatedRoutes = <String>[
  AppRoutes.home,
  AppRoutes.profile,
  AppRoutes.curriculum,
  AppRoutes.curriculumParts('program-cma'),
  AppRoutes.curriculumUnits('program-cma', 'cma-part-1'),
  AppRoutes.curriculumSubUnits('program-cma', 'unit-financial-planning'),
  AppRoutes.curriculumTopics('program-cma', 'subunit-budgeting'),
  AppRoutes.curriculumTopicDetail('topic-variance-analysis'),
  AppRoutes.studySessionActive,
  AppRoutes.studySessionSubmissionReview,
  AppRoutes.studySessionResults,
  AppRoutes.studySessionReview,
  AppRoutes.examSetup,
  AppRoutes.examActive,
  AppRoutes.examSubmissionReview,
  AppRoutes.examResults,
  AppRoutes.examPostReview,
  AppRoutes.performanceOverview,
  AppRoutes.performanceTopics,
  AppRoutes.performanceAttempts,
  AppRoutes.performanceAttemptDetail('perf-attempt-1'),
  AppRoutes.aiAnalysisOverview,
  AppRoutes.aiAnalysisTopic('topic-budgeting'),
  AppRoutes.aiAnalysisAttempt('perf-attempt-1'),
  AppRoutes.notifications,
  AppRoutes.notificationDetail('notif-1'),
  AppRoutes.notificationPreferences,
  AppRoutes.studyReminders,
  AppRoutes.studyReminderNew,
  AppRoutes.studyReminderEdit('reminder-1'),
  AppRoutes.aiTutor,
  AppRoutes.courses,
  AppRoutes.courseDetail('course-cma-part-1'),
  AppRoutes.lessonDetail('course-cma-part-1', 'lesson-intro-budgeting'),
];

final _publicRoutes = <String>[
  AppRoutes.login,
  AppRoutes.register,
  AppRoutes.forgotPassword,
  AppRoutes.resetPassword,
];

/// Phase 14B regression net: every route renders under the MADEEN theme
/// with no layout error on a small phone (320x568pt) at 130% text — in
/// English and Arabic, light and dark — and scrolling each screen to its
/// end raises nothing either.
void main() {
  Future<ProviderContainer> launch(
    WidgetTester tester, {
    required bool signedIn,
    required Locale locale,
    required ThemeMode themeMode,
  }) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer(
      (_) async => signedIn
          ? const AuthSession(user: _user, accessToken: 'token')
          : null,
    );
    when(() => auth.getCurrentUser())
        .thenAnswer((_) async => const Result.success(_user));
    final container = ProviderContainer(
      overrides: [
        ...accessOverrides(),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await container.read(localeProvider.notifier).setLocale(locale);
    await container.read(themeModeProvider.notifier).setThemeMode(themeMode);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> sweep(
    WidgetTester tester,
    ProviderContainer container,
    List<String> routes,
    Brightness brightness,
  ) async {
    // Collect every layout error across the whole sweep (with the route
    // and the widget that caused it) instead of stopping at the first —
    // the failure message is then a complete worklist.
    final errors = <String>[];
    var current = '';
    final original = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.toString();
      final creator = RegExp(r'relevant error-causing widget was:\s*\n\s*(.+)')
          .firstMatch(text)
          ?.group(1);
      errors.add(
        '$current: ${details.exceptionAsString().split('\n').first}'
        ' @ ${creator ?? '?'}',
      );
    };
    addTearDown(() => FlutterError.onError = original);

    final router = container.read(appRouterProvider);
    for (final route in routes) {
      current = route;
      // (scroll errors below are attributed to the same route)
      router.go(route);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(Scaffold).last);
      expect(
        MadeenTokens.of(context),
        brightness == Brightness.dark ? MadeenTokens.dark : MadeenTokens.light,
        reason: '$route is not on the MADEEN theme',
      );

      // Scroll every scrollable on screen to its end.
      final scrollables = find.byType(Scrollable);
      for (var i = 0; i < scrollables.evaluate().length && i < 3; i++) {
        final scrollable = scrollables.at(i);
        final state = tester.state<ScrollableState>(scrollable);
        if (state.position.axis != Axis.vertical) continue;
        for (var step = 0; step < 15; step++) {
          if (state.position.pixels >= state.position.maxScrollExtent) break;
          state.position.jumpTo(
            (state.position.pixels + 300).clamp(
              0,
              state.position.maxScrollExtent,
            ),
          );
          await tester.pump();
        }
      }
    }
    // Let the sample data sources' artificial-delay timers finish so none
    // are left pending at teardown.
    await tester.pump(const Duration(seconds: 2));
    FlutterError.onError = original;
    expect(errors.toSet().toList(), isEmpty);
  }

  for (final (name, locale, themeMode) in [
    ('English light', const Locale('en'), ThemeMode.light),
    ('Arabic light', const Locale('ar'), ThemeMode.light),
    ('English dark', const Locale('en'), ThemeMode.dark),
    ('Arabic dark', const Locale('ar'), ThemeMode.dark),
  ]) {
    final brightness = themeMode == ThemeMode.dark
        ? Brightness.dark
        : Brightness.light;

    testWidgets('every signed-in screen — $name, small phone, 130% text', (
      tester,
    ) async {
      final container = await launch(
        tester,
        signedIn: true,
        locale: locale,
        themeMode: themeMode,
      );
      await sweep(tester, container, _authenticatedRoutes, brightness);
    });

    testWidgets('every signed-out screen — $name, small phone, 130% text', (
      tester,
    ) async {
      final container = await launch(
        tester,
        signedIn: false,
        locale: locale,
        themeMode: themeMode,
      );
      await sweep(tester, container, _publicRoutes, brightness);
    });
  }
}
