import '../entities/notification_item.dart';

/// Mobile-side contract for a future push notification pipeline (FCM/APNs)
/// — **no backend push infrastructure exists yet** (see NOTIFICATIONS_API_
/// REQUIREMENTS.md's "Push notification status"). This interface exists so
/// the eventual real implementation (registering with FCM/APNs, wiring
/// their platform channels) is a drop-in replacement for
/// `../../data/services/mock_push_notification_handler.dart`, with no
/// change anywhere else in the app: the UI and `NotificationsRepository`
/// never call this directly — only the composition root would, once a real
/// implementation exists, to feed a freshly-arrived push straight into the
/// same [NotificationItem] shape the REST/mock list already uses.
abstract class PushNotificationHandler {
  /// Registers this device with the push provider and returns the token
  /// the backend would need to target it — `null` when no provider is
  /// configured (always the case for the mock implementation).
  Future<String?> registerDevice();

  /// Reverses [registerDevice] (e.g. on logout) so a signed-out device
  /// stops receiving pushes meant for the previous account.
  Future<void> unregisterDevice();

  /// Called by the composition root when a push arrives, already parsed
  /// into this app's own [NotificationItem] shape — never a raw provider
  /// payload, so nothing outside this one call site needs to know which
  /// push provider is in use.
  void onNotificationReceived(NotificationItem notification);
}
