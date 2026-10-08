import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ai_tutor/data/datasources/mock_ai_provider.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_message_role.dart';

void main() {
  late MockAiProvider provider;

  setUp(() {
    provider = MockAiProvider();
  });

  test(
    'matches "variance analysis" with a deterministic English reply',
    () async {
      final reply = await provider.generateReply(
        history: const [],
        userMessage: 'What is variance analysis?',
        languageCode: 'en',
      );

      expect(reply.role, TutorMessageRole.assistant);
      expect(reply.content, contains('Variance analysis'));
    },
  );

  test(
    'the same question always produces the same reply (deterministic)',
    () async {
      final first = await provider.generateReply(
        history: const [],
        userMessage: 'Explain contribution margin.',
        languageCode: 'en',
      );
      final second = await provider.generateReply(
        history: const [],
        userMessage: 'Explain contribution margin.',
        languageCode: 'en',
      );

      expect(first.content, second.content);
    },
  );

  test('matching is case-insensitive', () async {
    final reply = await provider.generateReply(
      history: const [],
      userMessage: 'EXPLAIN CONTRIBUTION MARGIN',
      languageCode: 'en',
    );

    expect(reply.content, contains('Contribution margin'));
  });

  test('responds in Arabic when languageCode is ar', () async {
    final reply = await provider.generateReply(
      history: const [],
      userMessage: 'ما هو تحليل الانحرافات؟',
      languageCode: 'ar',
    );

    expect(reply.content, contains('الانحرافات'));
  });

  test(
    'an unrecognized question falls back to a generic, honest reply',
    () async {
      final reply = await provider.generateReply(
        history: const [],
        userMessage: 'What is the capital of France?',
        languageCode: 'en',
      );

      expect(reply.content, contains('CMA/FMAA'));
    },
  );

  test('fallback reply is in Arabic when languageCode is ar', () async {
    final reply = await provider.generateReply(
      history: const [],
      userMessage: 'شيء غير معروف تمامًا',
      languageCode: 'ar',
    );

    expect(reply.content, isNotEmpty);
    expect(reply.content, contains('CMA'));
  });

  test('standard costing and fixed/variable cost topics resolve too', () async {
    final standardCosting = await provider.generateReply(
      history: const [],
      userMessage: 'How do I calculate standard costing variances?',
      languageCode: 'en',
    );
    expect(standardCosting.content, contains('Standard costing'));

    final fixedVariable = await provider.generateReply(
      history: const [],
      userMessage: 'What is the difference between fixed and variable costs?',
      languageCode: 'en',
    );
    expect(fixedVariable.content, contains('Fixed costs'));
  });
}
