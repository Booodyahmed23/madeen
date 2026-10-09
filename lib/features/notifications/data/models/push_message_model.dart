import 'dart:convert';

import '../../domain/entities/notification_action.dart';
import '../../domain/entities/push_message.dart';

/// A push's `data` payload — all strings, `action` being JSON or `"null"`
/// (contract §A10). Anything unreadable degrades to "no action", which
/// opens the notification's details.
PushMessage pushMessageFromData(Map<String, dynamic> data) {
  final id = data['notificationId'];
  return PushMessage(
    notificationId: id is String && id.isNotEmpty ? id : null,
    action: _action(data['action']),
  );
}

NotificationAction _action(Object? raw) {
  if (raw is! String || raw.isEmpty || raw == 'null') {
    return const NotificationAction();
  }
  try {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) return const NotificationAction();
    return NotificationAction(
      type: NotificationActionType.fromWire(json['type'] as String? ?? ''),
      targetId: json['targetId'] as String?,
      attemptType: json['attemptType'] as String?,
    );
  } on FormatException {
    return const NotificationAction();
  }
}
