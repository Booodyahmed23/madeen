import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/notifications/data/datasources/devices_remote_data_source.dart';
import 'package:mobile/features/notifications/data/models/push_message_model.dart';
import 'package:mobile/features/notifications/data/services/firebase_push_notification_handler.dart';
import 'package:mobile/features/notifications/domain/entities/notification_action.dart';
import 'package:mocktail/mocktail.dart';

class MockDevices extends Mock implements DevicesRemoteDataSource {}

class _FakeClient implements PushMessagingClient {
  bool permitted = true;
  String? token = 'token-1';
  Map<String, dynamic>? initial;
  final refresh = StreamController<String>.broadcast();
  final opened = StreamController<Map<String, dynamic>>.broadcast();
  final foreground = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Future<bool> requestPermission() async => permitted;

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<Map<String, dynamic>> get onMessageOpenedApp => opened.stream;

  @override
  Stream<Map<String, dynamic>> get onMessage => foreground.stream;

  @override
  Future<Map<String, dynamic>?> getInitialMessage() async => initial;
}

void main() {
  group('pushMessageFromData', () {
    test('reads the notification id and a JSON action', () {
      final message = pushMessageFromData({
        'notificationId': 'n1',
        'type': 'PERFORMANCE_UPDATE',
        'action':
            '{"type":"OPEN_ATTEMPT","targetId":"a1","attemptType":"STUDY"}',
      });

      expect(message.notificationId, 'n1');
      expect(message.action.type, NotificationActionType.openAttempt);
      expect(message.action.targetId, 'a1');
      expect(message.action.attemptType, 'STUDY');
    });

    test('"null", garbage or a missing action means no action', () {
      for (final action in ['null', '{not json', '', null]) {
        final message = pushMessageFromData({
          'notificationId': 'n1',
          'action': ?action,
        });
        expect(
          message.action.type,
          NotificationActionType.none,
          reason: action,
        );
      }
    });
  });

  group('FirebasePushNotificationHandler', () {
    late _FakeClient client;
    late MockDevices devices;
    late FirebasePushNotificationHandler handler;

    setUp(() {
      client = _FakeClient();
      devices = MockDevices();
      when(
        () => devices.register(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
          locale: any(named: 'locale'),
        ),
      ).thenAnswer((_) async {});
      when(() => devices.unregister(any())).thenAnswer((_) async {});
      handler = FirebasePushNotificationHandler(
        client,
        devices,
        platform: 'ANDROID',
      );
    });

    test('registers the token with platform and locale', () async {
      await handler.register(locale: 'ar');

      verify(
        () => devices.register(
          token: 'token-1',
          platform: 'ANDROID',
          locale: 'ar',
        ),
      ).called(1);
    });

    test('a refreshed token is registered again', () async {
      await handler.register(locale: 'en');

      client.refresh.add('token-2');
      await pumpEventQueue();

      verify(
        () => devices.register(
          token: 'token-2',
          platform: 'ANDROID',
          locale: 'en',
        ),
      ).called(1);
    });

    test('denied permission or no token registers nothing', () async {
      client.permitted = false;
      await handler.register(locale: 'en');
      client
        ..permitted = true
        ..token = null;
      await handler.register(locale: 'en');

      verifyNever(
        () => devices.register(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
          locale: any(named: 'locale'),
        ),
      );
    });

    test('a failed registration is swallowed', () async {
      when(
        () => devices.register(
          token: any(named: 'token'),
          platform: any(named: 'platform'),
          locale: any(named: 'locale'),
        ),
      ).thenThrow(Exception('offline'));

      await expectLater(handler.register(locale: 'en'), completes);
    });

    test('unregister sends the token and stops following refreshes', () async {
      await handler.register(locale: 'en');
      await handler.unregister();

      verify(() => devices.unregister('token-1')).called(1);
      client.refresh.add('token-3');
      await pumpEventQueue();
      verifyNever(
        () => devices.register(
          token: 'token-3',
          platform: any(named: 'platform'),
          locale: any(named: 'locale'),
        ),
      );
    });

    test('taps, foreground pushes and the launch push are parsed', () async {
      client.initial = {'notificationId': 'n0', 'action': 'null'};
      final taps = <String?>[];
      final foreground = <String?>[];
      handler.taps.listen((m) => taps.add(m.notificationId));
      handler.foregroundMessages.listen(
        (m) => foreground.add(m.notificationId),
      );

      client.opened.add({'notificationId': 'n1', 'action': 'null'});
      client.foreground.add({'notificationId': 'n2', 'action': 'null'});
      await pumpEventQueue();

      expect(taps, ['n1']);
      expect(foreground, ['n2']);
      expect((await handler.takeInitialTap())?.notificationId, 'n0');
      expect(await handler.takeInitialTap(), isNull, reason: 'read once');
    });
  });
}
