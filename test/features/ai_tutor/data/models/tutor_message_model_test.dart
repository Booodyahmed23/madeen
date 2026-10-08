import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_tutor/data/models/tutor_message_model.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_message_role.dart';

void main() {
  group('TutorMessageModel', () {
    test('fromJson / toJson round-trips every field', () {
      final json = {
        'id': 'tutor-msg-1',
        'role': 'ASSISTANT',
        'content': 'Variance analysis compares actual to planned results.',
        'timestamp': '2026-09-16T09:00:00.000Z',
      };

      final model = TutorMessageModel.fromJson(json);
      expect(model.role, TutorMessageRole.assistant);
      expect(model.toJson(), json);
    });

    test('toEntity carries every field across', () {
      final model = TutorMessageModel(
        id: 'tutor-msg-2',
        role: TutorMessageRole.user,
        content: 'What is contribution margin?',
        timestamp: DateTime(2026, 9, 16, 9),
      );

      final entity = model.toEntity();
      expect(entity.id, model.id);
      expect(entity.role, model.role);
      expect(entity.content, model.content);
      expect(entity.timestamp, model.timestamp);
      expect(entity.isFromUser, isTrue);
    });
  });
}
