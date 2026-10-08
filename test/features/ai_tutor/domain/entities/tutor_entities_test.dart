import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_conversation.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_message.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_message_role.dart';

TutorMessage _message(TutorMessageRole role, String content) => TutorMessage(
  id: 'id-$content',
  role: role,
  content: content,
  timestamp: DateTime(2026, 9, 1),
);

void main() {
  group('TutorMessage', () {
    test('isFromUser is true only for the user role', () {
      expect(_message(TutorMessageRole.user, 'hi').isFromUser, isTrue);
      expect(_message(TutorMessageRole.assistant, 'hi').isFromUser, isFalse);
    });
  });

  group('TutorConversation', () {
    test('isEmpty reflects whether any messages exist', () {
      final empty = TutorConversation(
        id: 'c1',
        messages: const [],
        createdAt: DateTime(2026, 9, 1),
      );
      expect(empty.isEmpty, isTrue);

      final withOne = empty.withMessage(_message(TutorMessageRole.user, 'hi'));
      expect(withOne.isEmpty, isFalse);
    });

    test('withMessage appends immutably, keeping id/createdAt', () {
      final conversation = TutorConversation(
        id: 'c1',
        messages: const [],
        createdAt: DateTime(2026, 9, 1),
      );
      final updated = conversation.withMessage(
        _message(TutorMessageRole.user, 'hello'),
      );

      expect(updated.id, conversation.id);
      expect(updated.createdAt, conversation.createdAt);
      expect(updated.messages, hasLength(1));
      expect(conversation.messages, isEmpty); // original untouched
    });

    test('withMessage preserves order across multiple appends', () {
      final conversation = TutorConversation(
        id: 'c1',
        messages: const [],
        createdAt: DateTime(2026, 9, 1),
      );
      final updated = conversation
          .withMessage(_message(TutorMessageRole.user, 'first'))
          .withMessage(_message(TutorMessageRole.assistant, 'second'));

      expect(updated.messages.map((m) => m.content), ['first', 'second']);
    });
  });

  group('TutorMessageRole wire mapping', () {
    test('round-trips every value', () {
      for (final role in TutorMessageRole.values) {
        expect(TutorMessageRole.fromWire(role.toWire()), role);
      }
    });

    test('throws for an unknown value', () {
      expect(
        () => TutorMessageRole.fromWire('NOT_A_ROLE'),
        throwsFormatException,
      );
    });
  });
}
