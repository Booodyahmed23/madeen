import '../../domain/entities/tutor_message.dart';
import '../../domain/entities/tutor_message_role.dart';

class TutorMessageModel {
  const TutorMessageModel({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
  });

  factory TutorMessageModel.fromJson(Map<String, dynamic> json) {
    return TutorMessageModel(
      id: json['id'] as String,
      role: TutorMessageRole.fromWire(json['role'] as String),
      content: json['content'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  final String id;
  final TutorMessageRole role;
  final String content;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.toWire(),
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  TutorMessage toEntity() =>
      TutorMessage(id: id, role: role, content: content, timestamp: timestamp);
}
