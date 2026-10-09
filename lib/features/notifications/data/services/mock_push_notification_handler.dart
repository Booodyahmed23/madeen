import '../../domain/entities/push_message.dart';
import '../../domain/services/push_notification_handler.dart';

/// Push while `PUSH_API_AVAILABLE` is off (or Firebase didn't start): does
/// nothing — no permission prompt, no API calls, no messages. Records calls
/// for tests.
class MockPushNotificationHandler implements PushNotificationHandler {
  final registeredLocales = <String>[];
  var unregisterCalls = 0;

  @override
  Future<void> register({required String locale}) async =>
      registeredLocales.add(locale);

  @override
  Future<void> unregister() async => unregisterCalls++;

  @override
  Stream<PushMessage> get taps => const Stream.empty();

  @override
  Stream<PushMessage> get foregroundMessages => const Stream.empty();

  @override
  Future<PushMessage?> takeInitialTap() async => null;
}
