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

  /// Whether to use the real Curriculum API (docs/MOBILE_API_CONTRACT.md
  /// §A2) rather than `CurriculumMockDataSource`. Set per environment via
  /// `--dart-define-from-file` (env/*.json); off by default, so a build
  /// without a define runs on sample data.
  static const bool isCurriculumApiAvailable = bool.fromEnvironment(
    'CURRICULUM_API_AVAILABLE',
  );

  /// Whether to use the real Study Session API (docs/MOBILE_API_CONTRACT.md
  /// §A3) rather than `StudySessionMockDataSource`. Same mechanism as
  /// [isCurriculumApiAvailable].
  static const bool isStudySessionApiAvailable = bool.fromEnvironment(
    'STUDY_SESSION_API_AVAILABLE',
  );

  /// Whether to use the real Exam Simulation API
  /// (docs/MOBILE_API_CONTRACT.md §A4) rather than `ExamMockDataSource`.
  /// Same mechanism as [isCurriculumApiAvailable].
  static const bool isExamSimulationApiAvailable = bool.fromEnvironment(
    'EXAM_SIMULATION_API_AVAILABLE',
  );

  /// Whether to use the real results API (docs/MOBILE_API_CONTRACT.md §A5)
  /// rather than `PerformanceMockDataSource` — which, when off, also makes
  /// the app record finished attempts on the device. Same mechanism as
  /// [isCurriculumApiAvailable].
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

  /// Whether to use the real Notifications / Study Reminders API
  /// (docs/MOBILE_API_CONTRACT.md §A9) rather than
  /// `NotificationsMockDataSource`. Same mechanism as
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

  /// Whether to register for push notifications (`POST /devices`,
  /// docs/MOBILE_API_CONTRACT.md §A10). Push also needs Firebase to start
  /// (see main.dart); otherwise the app runs without it.
  static const bool isPushApiAvailable = bool.fromEnvironment(
    'PUSH_API_AVAILABLE',
  );
}
