import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/notification_item.dart';
import '../../domain/services/push_notification_handler.dart';

/// **No push provider (FCM/APNs) is configured.** [registerDevice] always
/// returns `null` — there is no backend endpoint to send a token to yet
/// (see NOTIFICATIONS_API_REQUIREMENTS.md's "Push notification status") —
/// and [onNotificationReceived] only exists here so a future real
/// implementation's call sites (composition root wiring, tests) have
/// something to compile against today.
class MockPushNotificationHandler implements PushNotificationHandler {
  NotificationItem? lastReceived;

  @override
  Future<String?> registerDevice() async => null;

  @override
  Future<void> unregisterDevice() async {}

  @override
  void onNotificationReceived(NotificationItem notification) {
    lastReceived = notification;
  }
}

final pushNotificationHandlerProvider = Provider<MockPushNotificationHandler>((
  ref,
) {
  return MockPushNotificationHandler();
});
