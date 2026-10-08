import '../../domain/entities/notification_type.dart';
import '../../domain/entities/reminder_repeat.dart';
import '../../domain/entities/study_reminder.dart';
import '../../domain/entities/study_reminder_draft.dart';
import '../../domain/entities/weekday.dart';

class StudyReminderModel {
  const StudyReminderModel({
    required this.id,
    required this.title,
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.repeat,
    this.customDays = const {},
    this.notificationType = NotificationType.studyReminder,
    required this.createdAt,
    this.updatedAt,
  });

  factory StudyReminderModel.fromJson(Map<String, dynamic> json) {
    return StudyReminderModel(
      id: json['id'] as String,
      title: json['title'] as String,
      enabled: json['enabled'] as bool,
      hour: (json['hour'] as num).toInt(),
      minute: (json['minute'] as num).toInt(),
      repeat: ReminderRepeat.fromWire(json['repeat'] as String),
      customDays: (json['customDays'] as List? ?? const [])
          .map((d) => Weekday.fromWire(d as String))
          .toSet(),
      notificationType: json['notificationType'] == null
          ? NotificationType.studyReminder
          : NotificationType.fromWire(json['notificationType'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String id;
  final String title;
  final bool enabled;
  final int hour;
  final int minute;
  final ReminderRepeat repeat;
  final Set<Weekday> customDays;
  final NotificationType notificationType;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'enabled': enabled,
    'hour': hour,
    'minute': minute,
    'repeat': repeat.toWire(),
    'customDays': customDays.map((d) => d.toWire()).toList(),
    'notificationType': notificationType.toWire(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': (updatedAt ?? createdAt).toIso8601String(),
  };

  StudyReminderModel copyWith({bool? enabled}) => StudyReminderModel(
    id: id,
    title: title,
    enabled: enabled ?? this.enabled,
    hour: hour,
    minute: minute,
    repeat: repeat,
    customDays: customDays,
    notificationType: notificationType,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  StudyReminder toEntity() => StudyReminder(
    id: id,
    title: title,
    enabled: enabled,
    hour: hour,
    minute: minute,
    repeat: repeat,
    customDays: customDays,
    notificationType: notificationType,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// Wire body for the create/update endpoints — a draft has no `id`/
/// `createdAt` yet (the backend/mock assigns those), so it is not simply
/// [StudyReminderModel] with fields omitted; keeping it a distinct type
/// makes that omission a compile error instead of a runtime one.
Map<String, dynamic> studyReminderDraftToJson(StudyReminderDraft draft) => {
  'title': draft.title.trim(),
  'enabled': draft.enabled,
  'hour': draft.hour,
  'minute': draft.minute,
  'repeat': draft.repeat.toWire(),
  // Must be empty unless the reminder repeats on custom days.
  'customDays': draft.repeat == ReminderRepeat.custom
      ? [for (final day in draft.customDays) day.toWire()]
      : <String>[],
  'notificationType': draft.notificationType.toWire(),
};
