/// Per-category opt-in/out for both the in-app Notification Center and any
/// future push/local delivery of that category — one boolean per toggle the
/// Notification Preferences screen shows, grouped there under Study / Exams
/// / Performance / AI / Achievements / System (see this feature's README
/// for why "Study" and "Exams" are two sections but "AI"/"Achievements"/
/// "System" are each exactly one toggle).
class NotificationPreferences {
  const NotificationPreferences({
    this.studyReminders = true,
    this.dailyStudyReminders = true,
    this.examReminders = true,
    this.simulationReminders = true,
    this.performanceUpdates = true,
    this.achievements = true,
    this.systemNotifications = true,
  });

  final bool studyReminders;
  final bool dailyStudyReminders;
  final bool examReminders;
  final bool simulationReminders;
  final bool performanceUpdates;
  final bool achievements;
  final bool systemNotifications;

  NotificationPreferences copyWith({
    bool? studyReminders,
    bool? dailyStudyReminders,
    bool? examReminders,
    bool? simulationReminders,
    bool? performanceUpdates,
    bool? achievements,
    bool? systemNotifications,
  }) {
    return NotificationPreferences(
      studyReminders: studyReminders ?? this.studyReminders,
      dailyStudyReminders: dailyStudyReminders ?? this.dailyStudyReminders,
      examReminders: examReminders ?? this.examReminders,
      simulationReminders: simulationReminders ?? this.simulationReminders,
      performanceUpdates: performanceUpdates ?? this.performanceUpdates,
      achievements: achievements ?? this.achievements,
      systemNotifications: systemNotifications ?? this.systemNotifications,
    );
  }
}
