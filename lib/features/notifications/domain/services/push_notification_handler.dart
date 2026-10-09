import '../entities/push_message.dart';

/// Push notifications (contract §A10), independent of the provider: the
/// app composes this — registering the device, unregistering it before
/// sign-out, and routing taps — and never touches Firebase directly.
abstract class PushNotificationHandler {
  /// Asks for permission if needed, then registers this device's push token
  /// with the server in [locale] (`en` | `ar`, the language pushes are
  /// written in). Safe to repeat — on every start, sign-in or language
  /// change. Keeps the server updated when the token rotates.
  Future<void> register({required String locale});

  /// Stops pushes to this device for the signed-in account. Must run while
  /// the session is still valid (before logout or account deletion).
  Future<void> unregister();

  /// Pushes tapped while the app was running in the background.
  Stream<PushMessage> get taps;

  /// The push that launched the app from terminated, if any — read once.
  Future<PushMessage?> takeInitialTap();

  /// Pushes that arrived while the app was open (no system banner).
  Stream<PushMessage> get foregroundMessages;
}
