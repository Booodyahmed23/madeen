import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/locale_provider.dart';
import '../core/router/app_router.dart';
import '../features/auth/presentation/providers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_state.dart';
import '../features/notifications/data/repositories/notifications_repository_impl.dart';
import '../features/notifications/data/services/firebase_push_notification_handler.dart';
import '../features/notifications/domain/entities/push_message.dart';
import '../features/notifications/presentation/navigation/notification_action_resolver.dart';
import '../features/notifications/presentation/providers/notifications_providers.dart';

/// The language pushes are written in: the app's language, else the
/// device's — `en` or `ar`.
String pushLocale(Ref ref) {
  final code =
      ref.read(localeProvider)?.languageCode ??
      WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  return code == 'ar' ? 'ar' : 'en';
}

/// Push notifications for the app's lifetime (contract §A10): registers
/// this device while signed in (start, sign-in, language change), opens
/// what a tapped push points to — through the inbox's own resolver — and
/// refreshes the unread badge when a push arrives with the app open.
/// Unregistering before sign-out is a sign-out hook (app/sign_out_hooks.dart).
///
/// Kept alive for the app's lifetime by app/app.dart.
final pushSyncProvider = Provider<void>((ref) {
  final handler = ref.read(pushNotificationHandlerProvider);
  bool signedIn() => ref.read(authNotifierProvider) is AuthAuthenticated;

  ref.listen(
    authNotifierProvider.select(
      (state) => state is AuthAuthenticated ? state.user.id : null,
    ),
    (_, userId) async {
      if (userId == null) return;
      await handler.register(locale: pushLocale(ref));
      final initial = await handler.takeInitialTap();
      if (initial != null) openPush(ref, initial);
    },
    fireImmediately: true,
  );

  ref.listen(localeProvider, (_, _) {
    if (signedIn()) handler.register(locale: pushLocale(ref));
  });

  final taps = handler.taps.listen((message) {
    if (signedIn()) openPush(ref, message);
  });
  final foreground = handler.foregroundMessages.listen((_) {
    ref.invalidate(unreadNotificationCountProvider);
  });
  ref.onDispose(() {
    unawaited(taps.cancel());
    unawaited(foreground.cancel());
  });
});

/// Opens a tapped push: its action's screen (marking the notification
/// read), or — without a usable action — the notification itself, which
/// marks itself read when shown.
@visibleForTesting
void openPush(Ref ref, PushMessage message) {
  final id = message.notificationId;
  final actionRoute = NotificationActionResolver.resolve(message.action);
  final route =
      actionRoute ?? (id == null ? null : AppRoutes.notificationDetail(id));
  if (route == null) return;
  if (actionRoute != null && id != null) {
    ref.read(notificationsRepositoryProvider).markAsRead(id).then((_) {
      ref.invalidate(unreadNotificationCountProvider);
    });
  }
  // After the current frame: on a cold start the router may not be on
  // screen yet.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    ref.read(appRouterProvider).push(route);
  });
}
