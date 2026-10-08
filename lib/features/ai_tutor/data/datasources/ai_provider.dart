import '../models/tutor_message_model.dart';

/// Mobile-side contract for AI Tutor's actual AI capability — deliberately
/// not named `TutorDataSource` to match `docs/ARCHITECTURE.md` §17.1's own
/// vocabulary ("provider-abstracted (`AiProvider` interface) so the
/// underlying LLM vendor is swappable"). This is this feature's version of
/// every other feature's `XDataSource` seam (`NotificationsDataSource`,
/// `CurriculumDataSource`, ...): [TutorRepositoryImpl] depends on this
/// interface only, never on [MockAiProvider] directly.
///
/// **No implementation of this interface calls a real LLM in this phase.**
/// A future `RealAiProvider` (talking to a backend AI Tutor endpoint, which
/// itself would call an LLM vendor — no vendor has been chosen, see
/// `AI_TUTOR_API_REQUIREMENTS.md`'s "LLM provider status") is a drop-in
/// replacement for [MockAiProvider], with no change anywhere else in the
/// app once `AppConfig.isAiTutorApiAvailable` actually selects it.
abstract class AiProvider {
  /// Generates the assistant's reply to [userMessage]. [history] is every
  /// prior message in the conversation (oldest first) — a real LLM-backed
  /// implementation would send this as context; [MockAiProvider] reads
  /// only [userMessage] itself. [languageCode] is `'en'` or `'ar'` — the
  /// *response* language, matching the student's current effective UI
  /// language (mirrors `aiAnalysisLanguageProvider`'s own role for AI
  /// Analysis), independent of whichever language [userMessage] happens to
  /// be typed in.
  Future<TutorMessageModel> generateReply({
    required List<TutorMessageModel> history,
    required String userMessage,
    required String languageCode,
  });
}
