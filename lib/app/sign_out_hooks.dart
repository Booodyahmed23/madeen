import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/sign_out_hooks.dart';
import '../features/notifications/data/services/firebase_push_notification_handler.dart';
import 'push_sync.dart';

/// What must happen before signing out, while the session still works —
/// wired into [signOutHooksProvider] at the composition root (main.dart).
List<SignOutHook> appSignOutHooks(Ref ref) => [
  // `POST /devices/unregister` before logout or account deletion: neither
  // can remove the token itself (contract §A10).
  SignOutHook(
    before: () => ref.read(pushNotificationHandlerProvider).unregister(),
    cancelled: () => ref
        .read(pushNotificationHandlerProvider)
        .register(locale: pushLocale(ref)),
  ),
];
