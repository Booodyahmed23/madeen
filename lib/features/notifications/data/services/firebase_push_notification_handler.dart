import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../domain/entities/push_message.dart';
import '../../domain/services/push_notification_handler.dart';
import '../datasources/devices_remote_data_source.dart';
import '../models/push_message_model.dart';
import 'mock_push_notification_handler.dart';

/// The push provider side of [FirebasePushNotificationHandler], behind an
/// interface so registration and tap routing are testable without Firebase.
abstract class PushMessagingClient {
  /// `false` when the user denied notifications.
  Future<bool> requestPermission();

  /// `null` when the device can't receive pushes (e.g. iOS simulator).
  Future<String?> getToken();

  Stream<String> get onTokenRefresh;

  /// `data` of pushes tapped while the app ran in the background.
  Stream<Map<String, dynamic>> get onMessageOpenedApp;

  /// `data` of pushes that arrived while the app was open.
  Stream<Map<String, dynamic>> get onMessage;

  /// `data` of the push that launched the app, if any.
  Future<Map<String, dynamic>?> getInitialMessage();
}

/// Push through Firebase Cloud Messaging (contract §A10).
class FirebasePushNotificationHandler implements PushNotificationHandler {
  FirebasePushNotificationHandler(
    this._client,
    this._devices, {
    required this.platform,
  });

  final PushMessagingClient _client;
  final DevicesRemoteDataSource _devices;

  /// `IOS` | `ANDROID`.
  final String platform;

  String? _token;
  String? _locale;
  StreamSubscription<String>? _refresh;
  bool _initialTaken = false;

  @override
  Future<void> register({required String locale}) async {
    _locale = locale;
    try {
      if (!await _client.requestPermission()) return;
      final token = await _client.getToken();
      if (token == null) return;
      _token = token;
      await _devices.register(token: token, platform: platform, locale: locale);
      _refresh ??= _client.onTokenRefresh.listen(_onTokenRefresh);
    } catch (error) {
      // No push this time; the next start or sign-in tries again.
      debugPrint('Push registration failed: $error');
    }
  }

  Future<void> _onTokenRefresh(String token) async {
    _token = token;
    final locale = _locale;
    if (locale == null) return;
    try {
      await _devices.register(token: token, platform: platform, locale: locale);
    } catch (error) {
      debugPrint('Push token update failed: $error');
    }
  }

  @override
  Future<void> unregister() async {
    final token = _token ?? await _safeToken();
    await _refresh?.cancel();
    _refresh = null;
    _locale = null;
    if (token == null) return;
    await _devices.unregister(token);
  }

  Future<String?> _safeToken() async {
    try {
      return await _client.getToken();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<PushMessage> get taps =>
      _client.onMessageOpenedApp.map(pushMessageFromData);

  @override
  Stream<PushMessage> get foregroundMessages =>
      _client.onMessage.map(pushMessageFromData);

  @override
  Future<PushMessage?> takeInitialTap() async {
    if (_initialTaken) return null;
    _initialTaken = true;
    final data = await _client.getInitialMessage();
    return data == null ? null : pushMessageFromData(data);
  }
}

/// [PushMessagingClient] over firebase_messaging.
class FirebaseMessagingClient implements PushMessagingClient {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<String?> getToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await _messaging.getAPNSToken() == null) {
      // No APNs token (simulator, or APNs not set up): FCM can't deliver.
      return null;
    }
    return _messaging.getToken();
  }

  @override
  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<Map<String, dynamic>> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp.map((m) => m.data);

  @override
  Stream<Map<String, dynamic>> get onMessage =>
      FirebaseMessaging.onMessage.map((m) => m.data);

  @override
  Future<Map<String, dynamic>?> getInitialMessage() async =>
      (await _messaging.getInitialMessage())?.data;
}

/// Firebase push when `PUSH_API_AVAILABLE` is on and Firebase started (see
/// main.dart); otherwise the inert mock — no permission prompt, no calls.
final pushNotificationHandlerProvider = Provider<PushNotificationHandler>((
  ref,
) {
  if (!AppConfig.isPushApiAvailable || Firebase.apps.isEmpty) {
    return MockPushNotificationHandler();
  }
  return FirebasePushNotificationHandler(
    FirebaseMessagingClient(),
    ref.watch(devicesRemoteDataSourceProvider),
    platform: defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'ANDROID',
  );
});
