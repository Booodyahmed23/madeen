import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/notifications_repository_impl.dart';
import '../../domain/entities/notification_preferences.dart';
import '../../domain/repositories/notifications_repository.dart';
import 'notification_preferences_state.dart';

/// Owns the Notification Preferences screen's fetch and every toggle —
/// screens only read [NotificationPreferencesState] and call [setPreference],
/// never the repository directly (same rule as [NotificationsListNotifier]).
class NotificationPreferencesNotifier
    extends Notifier<NotificationPreferencesState> {
  late NotificationsRepository _repository;

  @override
  NotificationPreferencesState build() {
    _repository = ref.watch(notificationsRepositoryProvider);
    Future.microtask(load);
    return const NotificationPreferencesLoading();
  }

  Future<void> load() async {
    state = const NotificationPreferencesLoading();
    final result = await _repository.getNotificationPreferences();
    state = result.when(
      success: NotificationPreferencesReady.new,
      failure: NotificationPreferencesError.new,
    );
  }

  Future<void> retry() => load();

  /// Applies [updated] optimistically, then persists it — on failure, rolls
  /// back to the previous value and surfaces [NotificationPreferencesReady.
  /// saveError] so the switch the student just tapped visibly snaps back
  /// rather than silently disagreeing with what was saved.
  Future<void> setPreferences(NotificationPreferences updated) async {
    final current = state;
    if (current is! NotificationPreferencesReady) return;
    final previous = current.preferences;

    state = NotificationPreferencesReady(updated);
    final result = await _repository.updateNotificationPreferences(
      updated,
      previous: previous,
    );
    result.when(
      success: (saved) => state = NotificationPreferencesReady(saved),
      failure: (failure) {
        state = NotificationPreferencesReady(previous, saveError: failure);
      },
    );
  }
}

final notificationPreferencesNotifierProvider =
    NotifierProvider<
      NotificationPreferencesNotifier,
      NotificationPreferencesState
    >(NotificationPreferencesNotifier.new);
