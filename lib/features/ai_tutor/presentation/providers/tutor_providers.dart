import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/tutor_repository_impl.dart';
import '../../domain/entities/tutor_conversation.dart';
import '../../domain/entities/tutor_message.dart';
import '../../domain/entities/tutor_message_role.dart';
import '../../domain/repositories/tutor_repository.dart';
import 'tutor_conversation_state.dart';
import 'tutor_language_provider.dart';

/// Owns the whole AI Tutor conversation: sending a message, appending the
/// student's own message immediately (optimistic — see `sendMessage`),
/// awaiting the reply, and starting a fresh conversation. Screens only
/// read [TutorConversationState] and call these methods, never the
/// repository directly — same rule as every other notifier in this app.
class TutorConversationNotifier extends Notifier<TutorConversationState> {
  late TutorRepository _repository;
  late String _languageCode;

  @override
  TutorConversationState build() {
    _repository = ref.watch(tutorRepositoryProvider);
    _languageCode = ref.watch(tutorLanguageProvider);
    return TutorConversationState(conversation: _newConversation());
  }

  TutorConversation _newConversation() => TutorConversation(
    id: 'tutor-conv-${DateTime.now().microsecondsSinceEpoch}',
    messages: const [],
    createdAt: DateTime.now(),
  );

  /// `null`/blank [content] is a no-op — the Send button is disabled for
  /// that case too, but guarding here keeps this safe to call from
  /// anywhere (e.g. a suggested-prompt tap) without a second check.
  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty || state.isSending) return;

    final history = state.conversation.messages;
    final userMessage = TutorMessage(
      id: 'tutor-user-${DateTime.now().microsecondsSinceEpoch}',
      role: TutorMessageRole.user,
      content: trimmed,
      timestamp: DateTime.now(),
    );

    // The student's own message appears immediately, regardless of how
    // long the reply takes — never gated behind the network/mock delay.
    state = state.copyWith(
      conversation: state.conversation.withMessage(userMessage),
      isSending: true,
      clearError: true,
    );

    final result = await _repository.sendMessage(
      history: history,
      content: trimmed,
      languageCode: _languageCode,
    );

    result.when(
      success: (reply) {
        state = state.copyWith(
          conversation: state.conversation.withMessage(reply),
          isSending: false,
        );
      },
      failure: (failure) {
        // The student's message stays visible — only the reply failed:
        // retrying is just sending again, never losing what was already
        // typed.
        state = state.copyWith(isSending: false, error: failure);
      },
    );
  }

  void startNewConversation() {
    state = TutorConversationState(conversation: _newConversation());
  }
}

final tutorConversationNotifierProvider =
    NotifierProvider<TutorConversationNotifier, TutorConversationState>(
      TutorConversationNotifier.new,
    );
