/// Every destination a notification is allowed to deep-link into — a closed
/// set of already-existing app routes (Study Session Setup, Exam
/// Simulation, Performance, AI Analysis), never a raw route string on the
/// wire. This is what keeps [NotificationActionResolver] (see
/// `../../presentation/navigation/notification_action_resolver.dart`) a
/// single, centralized, exhaustively-`switch`-checked place that decides
/// navigation — nothing else in this feature hardcodes a route path.
///
/// [none] is the explicit "no action" value (e.g. a plain system notice);
/// it is distinct from an unrecognized wire value, which
/// [NotificationActionType.fromWire] maps to [unknown] instead of throwing,
/// so a client running behind a future backend release (that added a new
/// action type) degrades to "show details" rather than crashing.
enum NotificationActionType {
  openStudySessionSetup,
  openExamSetup,
  openPerformanceOverview,
  openTopicPerformance,
  openAttemptDetails,
  openAiAnalysisOverview,
  openAiAnalysisTopic,
  openAiAnalysisAttempt,
  none,

  /// A value the client doesn't recognize (or doesn't recognize yet) —
  /// resolved the same way [none] is: fall back to showing the
  /// notification's own details. See [NotificationActionType.fromWire].
  unknown;

  static NotificationActionType fromWire(String value) {
    switch (value) {
      case 'openStudySessionSetup':
        return NotificationActionType.openStudySessionSetup;
      case 'openExamSetup':
        return NotificationActionType.openExamSetup;
      case 'openPerformanceOverview':
        return NotificationActionType.openPerformanceOverview;
      case 'openTopicPerformance':
        return NotificationActionType.openTopicPerformance;
      case 'openAttemptDetails':
        return NotificationActionType.openAttemptDetails;
      case 'openAiAnalysisOverview':
        return NotificationActionType.openAiAnalysisOverview;
      case 'openAiAnalysisTopic':
        return NotificationActionType.openAiAnalysisTopic;
      case 'openAiAnalysisAttempt':
        return NotificationActionType.openAiAnalysisAttempt;
      case 'none':
        return NotificationActionType.none;
      default:
        return NotificationActionType.unknown;
    }
  }

  String toWire() => switch (this) {
    NotificationActionType.openStudySessionSetup => 'openStudySessionSetup',
    NotificationActionType.openExamSetup => 'openExamSetup',
    NotificationActionType.openPerformanceOverview => 'openPerformanceOverview',
    NotificationActionType.openTopicPerformance => 'openTopicPerformance',
    NotificationActionType.openAttemptDetails => 'openAttemptDetails',
    NotificationActionType.openAiAnalysisOverview => 'openAiAnalysisOverview',
    NotificationActionType.openAiAnalysisTopic => 'openAiAnalysisTopic',
    NotificationActionType.openAiAnalysisAttempt => 'openAiAnalysisAttempt',
    NotificationActionType.none => 'none',
    NotificationActionType.unknown => 'unknown',
  };
}

/// A notification's optional deep link — [type] says *where*, [targetId]
/// carries the id that destination needs (a topicId/attemptId), when it
/// needs one at all. Carrying no id is valid for [NotificationActionType.
/// openExamSetup]/[openPerformanceOverview]/[openAiAnalysisOverview] (none
/// of those routes take a path parameter) and is *not* enough evidence for
/// [openStudySessionSetup]/[openTopicPerformance]/[openAttemptDetails]/
/// [openAiAnalysisTopic]/[openAiAnalysisAttempt] to resolve — see
/// `NotificationActionResolver` for exactly which combinations resolve to a
/// route versus fall back to showing the notification's own details.
class NotificationAction {
  const NotificationAction({
    this.type = NotificationActionType.none,
    this.targetId,
  });

  final NotificationActionType type;
  final String? targetId;
}
