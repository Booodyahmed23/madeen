import '../../../../core/error/app_failure.dart';
import '../../domain/entities/tutor_conversation.dart';

/// AI Tutor's own state — unlike every other feature in this app, there is
/// nothing to fetch when the screen opens (a conversation starts empty,
/// in memory, immediately), so this is a single state shape rather than a
/// Loading/Ready/Error sealed hierarchy: [conversation] is always present,
/// [isSending] covers the one async gap (waiting for a reply), and [error]
/// is an inline, non-destructive annotation — a failed send never clears
/// the message the student already sent (see
/// [TutorConversationNotifier.sendMessage]).
class TutorConversationState {
  const TutorConversationState({
    required this.conversation,
    this.isSending = false,
    this.error,
  });

  final TutorConversation conversation;
  final bool isSending;
  final AppFailure? error;

  TutorConversationState copyWith({
    TutorConversation? conversation,
    bool? isSending,
    AppFailure? error,
    bool clearError = false,
  }) {
    return TutorConversationState(
      conversation: conversation ?? this.conversation,
      isSending: isSending ?? this.isSending,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
