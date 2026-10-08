import '../../../../core/error/result.dart';
import '../entities/tutor_message.dart';

/// The mobile app's only window onto AI Tutor — presentation code depends
/// on this interface, never on a concrete [AiProvider] (see
/// `../../data/datasources/ai_provider.dart`). Returns `Result`, same
/// error-handling seam as every other repository in this app, even though
/// `MockAiProvider` has no real failure mode today.
abstract class TutorRepository {
  /// Sends [content] as a new user message and returns the assistant's
  /// reply. [history] is every message in the conversation *before*
  /// [content] — passed explicitly (rather than this repository holding
  /// conversation state itself) so a future real implementation can send
  /// it as LLM context, and so this repository stays stateless like every
  /// other one in this app; [TutorConversationNotifier] owns the actual
  /// conversation.
  Future<Result<TutorMessage>> sendMessage({
    required List<TutorMessage> history,
    required String content,
    required String languageCode,
  });
}
