import 'notification_action.dart';

/// A push as the app sees it: the inbox notification it mirrors and where
/// tapping it leads (contract §A10 — `data: { notificationId, type,
/// action }`). Title and body are shown by the system, not the app.
class PushMessage {
  const PushMessage({this.notificationId, required this.action});

  final String? notificationId;
  final NotificationAction action;
}
