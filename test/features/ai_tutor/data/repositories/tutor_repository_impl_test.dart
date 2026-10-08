import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/features/ai_tutor/data/datasources/ai_provider.dart';
import 'package:mobile/features/ai_tutor/data/models/tutor_message_model.dart';
import 'package:mobile/features/ai_tutor/data/repositories/tutor_repository_impl.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_message_role.dart';
import 'package:mocktail/mocktail.dart';

class MockAiProvider extends Mock implements AiProvider {}

void main() {
  setUpAll(() {
    registerFallbackValue(<TutorMessageModel>[]);
  });

  late MockAiProvider provider;
  late TutorRepositoryImpl repository;

  setUp(() {
    provider = MockAiProvider();
    repository = TutorRepositoryImpl(provider);
  });

  test(
    'sendMessage maps the provider reply to a domain entity on success',
    () async {
      when(
        () => provider.generateReply(
          history: any(named: 'history'),
          userMessage: any(named: 'userMessage'),
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer(
        (_) async => TutorMessageModel(
          id: 'tutor-msg-1',
          role: TutorMessageRole.assistant,
          content: 'Variance analysis compares actual to planned results.',
          timestamp: DateTime(2026, 9, 1),
        ),
      );

      final result = await repository.sendMessage(
        history: const [],
        content: 'What is variance analysis?',
        languageCode: 'en',
      );

      expect(
        result.when(success: (m) => m.content, failure: (_) => null),
        'Variance analysis compares actual to planned results.',
      );
    },
  );

  test(
    'sendMessage passes history and languageCode through unchanged',
    () async {
      when(
        () => provider.generateReply(
          history: any(named: 'history'),
          userMessage: any(named: 'userMessage'),
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer(
        (_) async => TutorMessageModel(
          id: 'tutor-msg-1',
          role: TutorMessageRole.assistant,
          content: 'reply',
          timestamp: DateTime(2026, 9, 1),
        ),
      );

      await repository.sendMessage(
        history: const [],
        content: 'hello',
        languageCode: 'ar',
      );

      verify(
        () => provider.generateReply(
          history: any(named: 'history'),
          userMessage: 'hello',
          languageCode: 'ar',
        ),
      ).called(1);
    },
  );

  test('sendMessage maps an unexpected exception to UnknownFailure', () async {
    when(
      () => provider.generateReply(
        history: any(named: 'history'),
        userMessage: any(named: 'userMessage'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenThrow(StateError('boom'));

    final result = await repository.sendMessage(
      history: const [],
      content: 'hello',
      languageCode: 'en',
    );

    expect(
      result.when(success: (_) => null, failure: (f) => f.runtimeType),
      UnknownFailure,
    );
  });
}
