import '../../domain/entities/notification_preferences.dart';

/// The seven preference keys, in API order (contract §A9).
NotificationPreferences notificationPreferencesFromJson(
  Map<String, dynamic> json,
) => NotificationPreferences(
  studyReminders: json['studyReminders'] as bool? ?? true,
  dailyStudyReminders: json['dailyStudyReminders'] as bool? ?? true,
  examReminders: json['examReminders'] as bool? ?? true,
  simulationReminders: json['simulationReminders'] as bool? ?? true,
  performanceUpdates: json['performanceUpdates'] as bool? ?? true,
  achievements: json['achievements'] as bool? ?? true,
  systemNotifications: json['systemNotifications'] as bool? ?? true,
);

Map<String, bool> notificationPreferencesToJson(NotificationPreferences p) => {
  'studyReminders': p.studyReminders,
  'dailyStudyReminders': p.dailyStudyReminders,
  'examReminders': p.examReminders,
  'simulationReminders': p.simulationReminders,
  'performanceUpdates': p.performanceUpdates,
  'achievements': p.achievements,
  'systemNotifications': p.systemNotifications,
};

/// Only the keys that differ — `PATCH /notifications/preferences` accepts
/// any subset.
Map<String, bool> notificationPreferencesChanges(
  NotificationPreferences previous,
  NotificationPreferences updated,
) {
  final before = notificationPreferencesToJson(previous);
  return {
    for (final entry in notificationPreferencesToJson(updated).entries)
      if (before[entry.key] != entry.value) entry.key: entry.value,
  };
}
