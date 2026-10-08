/// Compile-time environment configuration.
///
/// Values come from `--dart-define-from-file=env/<name>.json` (see the env/
/// folder at the repo root and docs/SETUP.md) rather than a bundled `.env`
/// asset — these are non-secret, public API endpoints, so baking them in at
/// build time (per environment) is both simpler and more idiomatic Flutter
/// than shipping a dotenv file inside the app package.
library;

import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._();

  static const String environmentName = String.fromEnvironment(
    'ENV_NAME',
    defaultValue: 'development',
  );

  static const String _apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/api/v1',
  );

  /// The API base URL. A `localhost` URL (the dev default) is rewritten to
  /// `10.0.2.2` on Android, where the emulator reaches the host machine
  /// through that address rather than its own loopback (contract §G1).
  static String get apiBaseUrl => resolveApiBaseUrl(_apiBaseUrl);

  @visibleForTesting
  static String resolveApiBaseUrl(
    String configured, {
    TargetPlatform? platform,
  }) {
    final uri = Uri.parse(configured);
    final isAndroid =
        (platform ?? defaultTargetPlatform) == TargetPlatform.android;
    if (!isAndroid || uri.host != 'localhost') return configured;
    return uri.replace(host: '10.0.2.2').toString();
  }

  static bool get isProduction => environmentName == 'production';

  /// Whether the backend actually exposes the Curriculum endpoints this app
  /// expects (see mobile/CURRICULUM_API_REQUIREMENTS.md) — as of Phase 3
  /// they do not exist yet, so this defaults to `false` and the curriculum
  /// feature falls back to `CurriculumMockDataSource`. Flip via
  /// `--dart-define-from-file` (env/*.json) once the backend ships them —
  /// no other code change is needed, see curriculum_providers.dart.
  static const bool isCurriculumApiAvailable = bool.fromEnvironment(
    'CURRICULUM_API_AVAILABLE',
  );

  /// Whether the backend exposes the Study Session / Question Bank
  /// endpoints this app expects (see
  /// mobile/STUDY_SESSION_API_REQUIREMENTS.md) — as of Phase 4 they do not
  /// exist yet, so this defaults to `false` and the feature falls back to
  /// `StudySessionMockDataSource`. Same flip-one-flag mechanism as
  /// [isCurriculumApiAvailable].
  static const bool isStudySessionApiAvailable = bool.fromEnvironment(
    'STUDY_SESSION_API_AVAILABLE',
  );

  /// Whether the backend exposes the Exam Simulation endpoints this app
  /// expects (see mobile/EXAM_SIMULATION_API_REQUIREMENTS.md) — as of
  /// Phase 5 they do not exist yet, so this defaults to `false` and the
  /// feature falls back to `ExamMockDataSource`. Same flip-one-flag
  /// mechanism as [isCurriculumApiAvailable].
  static const bool isExamSimulationApiAvailable = bool.fromEnvironment(
    'EXAM_SIMULATION_API_AVAILABLE',
  );

  /// Whether the backend exposes the Performance Analytics endpoints this
  /// app expects (see mobile/PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md) —
  /// as of Phase 6 they do not exist yet, so this defaults to `false` and
  /// the feature falls back to `PerformanceMockDataSource`. Same
  /// flip-one-flag mechanism as [isCurriculumApiAvailable].
  static const bool isPerformanceApiAvailable = bool.fromEnvironment(
    'PERFORMANCE_API_AVAILABLE',
  );

  /// Whether the backend exposes the AI Analysis endpoints proposed in
  /// mobile/AI_ANALYSIS_API_REQUIREMENTS.md — as of Phase 7 they do not
  /// exist yet (no AIAnalysis module on the backend), so this defaults to
  /// `false` and the feature falls back to `AiAnalysisMockDataSource`,
  /// which derives its content from the exact same Performance Analytics
  /// numbers already on screen (via `performanceRepositoryProvider`) rather
  /// than inventing its own. Independent of [isPerformanceApiAvailable] —
  /// "real Performance data, mock AI analysis" is a valid intermediate
  /// deployment state. Same flip-one-flag mechanism as
  /// [isCurriculumApiAvailable].
  static const bool isAiAnalysisApiAvailable = bool.fromEnvironment(
    'AI_ANALYSIS_API_AVAILABLE',
  );

  /// Whether the backend exposes the Notifications / Study Reminders
  /// endpoints this app expects (see mobile/NOTIFICATIONS_API_
  /// REQUIREMENTS.md) — as of Phase 8 they do not exist yet, so this
  /// defaults to `false` and the feature falls back to
  /// `NotificationsMockDataSource`. Same flip-one-flag mechanism as
  /// [isCurriculumApiAvailable].
  static const bool isNotificationsApiAvailable = bool.fromEnvironment(
    'NOTIFICATIONS_API_AVAILABLE',
  );

  /// Whether the backend exposes the AI Tutor endpoints this app expects —
  /// as of Phase 10 they do not exist yet (no `AITutor` module on the
  /// backend, and no LLM vendor has been chosen — see `docs/ARCHITECTURE.md`
  /// §17.1/§30), so this defaults to `false` and the feature falls back to
  /// `MockAiProvider`. Unlike every other `is*ApiAvailable` flag, flipping
  /// this to `true` currently has **no effect** — there is no
  /// `RealAiProvider` implementation to select yet; the flag exists only so
  /// the mobile architecture is ready for one without another code change
  /// once the backend module and LLM vendor decision both exist.
  static const bool isAiTutorApiAvailable = bool.fromEnvironment(
    'AI_TUTOR_API_AVAILABLE',
  );

  /// Whether the backend exposes the Course endpoints this app expects —
  /// as of Phase 11 they do not exist yet (no `Course` module on the
  /// backend — see `docs/ARCHITECTURE.md` §13), so this defaults to
  /// `false` and the feature falls back to `CourseMockDataSource`. Same
  /// flip-one-flag mechanism as [isCurriculumApiAvailable] — once a real
  /// backend module exists, only `data/datasources/course_data_source.dart`
  /// needs to start branching on this; no other mobile code changes.
  static const bool isCourseApiAvailable = bool.fromEnvironment(
    'COURSE_API_AVAILABLE',
  );

  /// Whether the backend exposes push device registration (`POST /devices`,
  /// `POST /devices/unregister` — contract Part B). Off until the API
  /// ships it.
  static const bool isPushApiAvailable = bool.fromEnvironment(
    'PUSH_API_AVAILABLE',
  );
}
