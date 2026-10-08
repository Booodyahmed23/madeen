import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/ai_tutor/data/repositories/tutor_repository_impl.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_message.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_message_role.dart';
import 'package:mobile/features/ai_tutor/domain/repositories/tutor_repository.dart';
import 'package:mobile/features/ai_tutor/presentation/providers/tutor_providers.dart';
import 'package:mocktail/mocktail.dart';

class MockTutorRepository extends Mock implements TutorRepository {}

TutorMessage _assistantMessage(String content) => TutorMessage(
  id: 'assistant-1',
  role: TutorMessageRole.assistant,
  content: content,
  timestamp: DateTime(2026, 9, 1),
);

void main() {
  // tutorLanguageProvider transitively watches localeProvider, whose
  // LocaleNotifier.build() reads SharedPreferences — needs plugin bindings
  // initialized (even for a plain, non-widget test) and a mock in-memory
  // store, since there's no real platform channel to answer it here.
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() {
    registerFallbackValue(<TutorMessage>[]);
  });

  late MockTutorRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockTutorRepository();
    container = ProviderContainer(
      overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
  });

  test('starts with an empty conversation, not sending, no error', () {
    final state = container.read(tutorConversationNotifierProvider);
    expect(state.conversation.isEmpty, isTrue);
    expect(state.isSending, isFalse);
    expect(state.error, isNull);
  });

  test('sendMessage appends the user message immediately, before the '
      'reply resolves', () async {
    final completer = Completer<Result<TutorMessage>>();
    when(
      () => repository.sendMessage(
        history: any(named: 'history'),
        content: any(named: 'content'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) => completer.future);

    final notifier = container.read(tutorConversationNotifierProvider.notifier);
    final future = notifier.sendMessage('What is variance analysis?');
    await Future<void>.delayed(Duration.zero);

    final state = container.read(tutorConversationNotifierProvider);
    expect(state.conversation.messages, hasLength(1));
    expect(state.conversation.messages.single.isFromUser, isTrue);
    expect(state.isSending, isTrue);

    completer.complete(Result.success(_assistantMessage('reply')));
    await future;
  });

  test('a successful reply is appended after the user message', () async {
    when(
      () => repository.sendMessage(
        history: any(named: 'history'),
        content: any(named: 'content'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer(
      (_) async => Result.success(_assistantMessage('Here you go.')),
    );

    final notifier = container.read(tutorConversationNotifierProvider.notifier);
    await notifier.sendMessage('hello');

    final state = container.read(tutorConversationNotifierProvider);
    expect(state.conversation.messages, hasLength(2));
    expect(state.conversation.messages.last.content, 'Here you go.');
    expect(state.isSending, isFalse);
    expect(state.error, isNull);
  });

  test(
    'a failed reply keeps the user message and surfaces the error',
    () async {
      when(
        () => repository.sendMessage(
          history: any(named: 'history'),
          content: any(named: 'content'),
          languageCode: any(named: 'languageCode'),
        ),
      ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

      final notifier = container.read(
        tutorConversationNotifierProvider.notifier,
      );
      await notifier.sendMessage('hello');

      final state = container.read(tutorConversationNotifierProvider);
      expect(state.conversation.messages, hasLength(1)); // user message kept
      expect(state.conversation.messages.single.isFromUser, isTrue);
      expect(state.isSending, isFalse);
      expect(state.error, isA<NetworkFailure>());
    },
  );

  test('a blank message is a no-op', () async {
    final notifier = container.read(tutorConversationNotifierProvider.notifier);
    await notifier.sendMessage('   ');

    expect(
      container.read(tutorConversationNotifierProvider).conversation.isEmpty,
      isTrue,
    );
    verifyNever(
      () => repository.sendMessage(
        history: any(named: 'history'),
        content: any(named: 'content'),
        languageCode: any(named: 'languageCode'),
      ),
    );
  });

  test('startNewConversation clears messages and any error', () async {
    when(
      () => repository.sendMessage(
        history: any(named: 'history'),
        content: any(named: 'content'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

    final notifier = container.read(tutorConversationNotifierProvider.notifier);
    await notifier.sendMessage('hello');
    expect(container.read(tutorConversationNotifierProvider).error, isNotNull);

    notifier.startNewConversation();

    final state = container.read(tutorConversationNotifierProvider);
    expect(state.conversation.isEmpty, isTrue);
    expect(state.error, isNull);
  });
}
