import '../../domain/entities/notification_preferences.dart';

class NotificationPreferencesModel {
  const NotificationPreferencesModel({
    required this.studyReminders,
    required this.dailyStudyReminders,
    required this.examReminders,
    required this.simulationReminders,
    required this.performanceUpdates,
    required this.aiRecommendations,
    required this.achievements,
    required this.systemNotifications,
  });

  factory NotificationPreferencesModel.fromEntity(
    NotificationPreferences entity,
  ) {
    return NotificationPreferencesModel(
      studyReminders: entity.studyReminders,
      dailyStudyReminders: entity.dailyStudyReminders,
      examReminders: entity.examReminders,
      simulationReminders: entity.simulationReminders,
      performanceUpdates: entity.performanceUpdates,
      aiRecommendations: entity.aiRecommendations,
      achievements: entity.achievements,
      systemNotifications: entity.systemNotifications,
    );
  }

  factory NotificationPreferencesModel.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesModel(
      studyReminders: json['studyReminders'] as bool,
      dailyStudyReminders: json['dailyStudyReminders'] as bool,
      examReminders: json['examReminders'] as bool,
      simulationReminders: json['simulationReminders'] as bool,
      performanceUpdates: json['performanceUpdates'] as bool,
      aiRecommendations: json['aiRecommendations'] as bool,
      achievements: json['achievements'] as bool,
      systemNotifications: json['systemNotifications'] as bool,
    );
  }

  final bool studyReminders;
  final bool dailyStudyReminders;
  final bool examReminders;
  final bool simulationReminders;
  final bool performanceUpdates;
  final bool aiRecommendations;
  final bool achievements;
  final bool systemNotifications;

  Map<String, dynamic> toJson() => {
    'studyReminders': studyReminders,
    'dailyStudyReminders': dailyStudyReminders,
    'examReminders': examReminders,
    'simulationReminders': simulationReminders,
    'performanceUpdates': performanceUpdates,
    'aiRecommendations': aiRecommendations,
    'achievements': achievements,
    'systemNotifications': systemNotifications,
  };

  NotificationPreferences toEntity() => NotificationPreferences(
    studyReminders: studyReminders,
    dailyStudyReminders: dailyStudyReminders,
    examReminders: examReminders,
    simulationReminders: simulationReminders,
    performanceUpdates: performanceUpdates,
    aiRecommendations: aiRecommendations,
    achievements: achievements,
    systemNotifications: systemNotifications,
  );
}
