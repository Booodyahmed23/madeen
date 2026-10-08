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
      // With a topic, straight to its study setup; otherwise the curriculum
      // to pick one.
      NotificationActionType.openStudySetup =>
        targetId == null
            ? AppRoutes.curriculum
            : AppRoutes.curriculumTopicDetail(targetId),
      NotificationActionType.openExamSetup => AppRoutes.examSetup,
      NotificationActionType.openPerformance => AppRoutes.performanceOverview,
      // No per-topic Performance route exists — the Topic Performance list
      // is the closest existing destination (see AppRoutes.performanceTopics).
      NotificationActionType.openTopicPerformance =>
        AppRoutes.performanceTopics,
      NotificationActionType.openAttempt =>
        targetId == null ? null : AppRoutes.performanceAttemptDetail(targetId),
      NotificationActionType.openPlans => AppRoutes.plans,
      NotificationActionType.none => null,
      // A wire value this build doesn't recognize — same "fall back to
      // details" degradation as `none`, see NotificationActionType.fromWire.
      NotificationActionType.unknown => null,
    };
  }
}
