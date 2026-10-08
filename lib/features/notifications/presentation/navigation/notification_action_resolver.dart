import '../../../../core/router/app_router.dart';
import '../../domain/entities/notification_action.dart';

/// Centralizes every decision about *where* a [NotificationAction] leads —
/// the single place in this feature allowed to know an `AppRoutes` path, so
/// [NotificationActionType] additions or route changes touch exactly this
/// file, never a screen. Referenced from `notification_action.dart`'s own
/// doc comment as the intended home for this logic.
///
/// Deliberately conservative: a combination this resolver can't confidently
/// turn into an existing route (a missing required id, or an action type
/// this build doesn't recognize) resolves to `null` rather than guessing —
/// callers fall back to showing the notification's own details, which is
/// always safe.
abstract final class NotificationActionResolver {
  static String? resolve(NotificationAction action) {
    final targetId = action.targetId;
    return switch (action.type) {
      NotificationActionType.openStudySessionSetup =>
        targetId == null ? null : AppRoutes.curriculumTopicDetail(targetId),
      NotificationActionType.openExamSetup => AppRoutes.examSetup,
      NotificationActionType.openPerformanceOverview =>
        AppRoutes.performanceOverview,
      // No per-topic Performance route exists yet — the Topic Performance
      // list is the closest existing destination, not a route invented for
      // this resolver (see AppRoutes.performanceTopics).
      NotificationActionType.openTopicPerformance =>
        AppRoutes.performanceTopics,
      NotificationActionType.openAttemptDetails =>
        targetId == null ? null : AppRoutes.performanceAttemptDetail(targetId),
      NotificationActionType.openAiAnalysisOverview =>
        AppRoutes.aiAnalysisOverview,
      NotificationActionType.openAiAnalysisTopic =>
        targetId == null ? null : AppRoutes.aiAnalysisTopic(targetId),
      NotificationActionType.openAiAnalysisAttempt =>
        targetId == null ? null : AppRoutes.aiAnalysisAttempt(targetId),
      NotificationActionType.none => null,
      // A wire value this build doesn't recognize — same "fall back to
      // details" degradation as `none`, see NotificationActionType.fromWire.
      NotificationActionType.unknown => null,
    };
  }
}
