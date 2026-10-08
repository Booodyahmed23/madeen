import '../../../../core/error/app_failure.dart';
import '../../domain/entities/notification_preferences.dart';

/// Notification Preferences screen's own state machine — same
/// Loading/Ready/Error shape as [NotificationsListState], one layer over a
/// single [NotificationPreferences] value instead of a list.
sealed class NotificationPreferencesState {
  const NotificationPreferencesState();
}

class NotificationPreferencesLoading extends NotificationPreferencesState {
  const NotificationPreferencesLoading();
}

class NotificationPreferencesReady extends NotificationPreferencesState {
  const NotificationPreferencesReady(this.preferences, {this.saveError});

  final NotificationPreferences preferences;

  /// Set only while a just-attempted toggle failed to persist — the screen
  /// keeps showing the last-known-good [preferences] (already rolled back
  /// by the notifier) rather than dropping into a full error view, since
  /// the rest of the list is still perfectly usable.
  final AppFailure? saveError;
}

class NotificationPreferencesError extends NotificationPreferencesState {
  const NotificationPreferencesError(this.failure);

  final AppFailure failure;
}
