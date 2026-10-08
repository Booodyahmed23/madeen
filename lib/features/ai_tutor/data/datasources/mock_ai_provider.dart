import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ai_provider.dart';
import '../models/tutor_message_model.dart';
import '../../domain/entities/tutor_message_role.dart';

/// Deterministic, keyword-matched study-assistance replies — **not a real
/// AI service**. Matching checks each topic's English keywords
/// case-insensitively and its Arabic keywords as-is (Arabic has no
/// case-folding concept), against a small, fixed set of CMA/FMAA study
/// topics (chosen to match this feature's own worked examples in
/// `AI_TUTOR_API_REQUIREMENTS.md`) — so the same question always produces
/// the same answer, and a question typed in either language matches the
/// same topic regardless of which language the *reply* is in (the reply
/// language always follows [languageCode] — the student's current
/// effective UI language — never the detected input language, same rule
/// `AiAnalysisMockDataSource` already follows). Falls back to one generic
/// "I can help you study..." reply for anything unmatched, in both
/// supported languages, rather than pretending to understand a question
/// it doesn't recognize.
class MockAiProvider implements AiProvider {
  static const _artificialDelay = Duration(milliseconds: 500);

  @override
  Future<TutorMessageModel> generateReply({
    required List<TutorMessageModel> history,
    required String userMessage,
    required String languageCode,
  }) async {
    await Future<void>.delayed(_artificialDelay);

    final isArabic = languageCode == 'ar';
    final content =
        _matchTopic(userMessage)?.reply(isArabic) ?? _fallback(isArabic);

    return TutorMessageModel(
      id: 'tutor-msg-${DateTime.now().microsecondsSinceEpoch}',
      role: TutorMessageRole.assistant,
      content: content,
      timestamp: DateTime.now(),
    );
  }

  _Topic? _matchTopic(String message) {
    final normalizedEn = message.toLowerCase();
    for (final topic in _topics) {
      final matchesEn = topic.keywordsEn.any(normalizedEn.contains);
      final matchesAr = topic.keywordsAr.any(message.contains);
      if (matchesEn || matchesAr) return topic;
    }
    return null;
  }

  String _fallback(bool isArabic) => isArabic
      ? 'يمكنني المساعدة في مفاهيم المذاكرة لامتحان CMA أو FMAA — جرّب أن '
            'تسأل عن موضوع محدد مثل تحليل الانحرافات أو هامش المساهمة.'
      : "I can help with CMA/FMAA study concepts — try asking about a "
            'specific topic, like variance analysis or contribution margin.';

  static final _topics = [
    _Topic(
      // Deliberately not the bare words "variance"/"انحراف" — both are
      // substrings of "variances"/"انحرافات التكلفة", which would wrongly
      // steal a Standard Costing question since this topic is checked
      // first (see `_matchTopic`'s doc comment).
      keywordsEn: const ['variance analysis'],
      keywordsAr: const ['تحليل الانحرافات', 'الانحرافات'],
      replyEn:
          'Variance analysis compares actual results with planned or '
          'standard results to identify and explain differences.',
      replyAr:
          'يُقارن تحليل الانحرافات النتائج الفعلية بالنتائج المخططة أو '
          'المعيارية لتحديد الفروقات وتفسيرها.',
    ),
    _Topic(
      keywordsEn: const ['contribution margin'],
      keywordsAr: const ['هامش المساهمة'],
      replyEn:
          'Contribution margin is sales revenue minus variable costs. It '
          'shows how much remains to cover fixed costs and contribute to '
          'profit.',
      replyAr:
          'هامش المساهمة هو إيرادات المبيعات مطروحًا منها التكاليف '
          'المتغيرة. يُظهر المبلغ المتبقي لتغطية التكاليف الثابتة '
          'والمساهمة في الربح.',
    ),
    _Topic(
      keywordsEn: const ['fixed and variable', 'variable cost', 'fixed cost'],
      keywordsAr: const ['التكاليف الثابتة', 'التكاليف المتغيرة'],
      replyEn:
          'Fixed costs stay the same regardless of production or sales '
          'volume (e.g. rent). Variable costs change in direct proportion '
          'to volume (e.g. raw materials).',
      replyAr:
          'تبقى التكاليف الثابتة كما هي بصرف النظر عن حجم الإنتاج أو '
          'المبيعات (مثل الإيجار). أما التكاليف المتغيرة فتتغير بتناسب '
          'مباشر مع الحجم (مثل المواد الخام).',
    ),
    _Topic(
      keywordsEn: const ['standard costing', 'standard cost'],
      keywordsAr: const ['التكلفة المعيارية', 'انحرافات التكلفة'],
      replyEn:
          'Standard costing variances are calculated by comparing actual '
          'cost to the predetermined standard cost, split into a price/rate '
          'variance (did we pay more or less per unit?) and a '
          'quantity/efficiency variance (did we use more or less than '
          'planned?).',
      replyAr:
          'تُحسب انحرافات التكلفة المعيارية بمقارنة التكلفة الفعلية '
          'بالتكلفة المعيارية المحددة مسبقًا، وتُقسم إلى انحراف السعر (هل '
          'دفعنا أكثر أم أقل لكل وحدة؟) وانحراف الكمية/الكفاءة (هل '
          'استخدمنا أكثر أم أقل من المخطط؟).',
    ),
  ];
}

class _Topic {
  const _Topic({
    required this.keywordsEn,
    required this.keywordsAr,
    required this.replyEn,
    required this.replyAr,
  });

  final List<String> keywordsEn;
  final List<String> keywordsAr;
  final String replyEn;
  final String replyAr;

  String reply(bool isArabic) => isArabic ? replyAr : replyEn;
}

final aiProviderProvider = Provider<AiProvider>((ref) {
  // AppConfig.isAiTutorApiAvailable is intentionally not checked here yet —
  // see that flag's own doc comment: there is no RealAiProvider to select
  // until a backend AI Tutor module and an LLM vendor both exist.
  return MockAiProvider();
});
