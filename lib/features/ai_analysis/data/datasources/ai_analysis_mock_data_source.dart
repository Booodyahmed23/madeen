import '../../../../core/error/result.dart';
import '../../../performance/domain/entities/attempt_details.dart';
import '../../../performance/domain/entities/attempt_summary.dart';
import '../../../performance/domain/entities/attempt_type.dart';
import '../../../performance/domain/entities/performance_filter.dart';
import '../../../performance/domain/entities/performance_overview.dart';
import '../../../performance/domain/entities/topic_performance.dart';
import '../../../performance/domain/repositories/performance_repository.dart';
import '../../domain/entities/ai_analysis_scope.dart';
import '../../domain/entities/ai_insight.dart';
import '../models/ai_analysis_metadata_model.dart';
import '../models/ai_analysis_model.dart';
import '../models/ai_insight_model.dart';
import '../models/ai_recommendation_model.dart';
import '../models/ai_topic_insight_model.dart';
import 'ai_analysis_data_source.dart';

const _strengthKind = AiInsightKind.strength;
const _weaknessKind = AiInsightKind.weakness;
const _patternKind = AiInsightKind.pattern;

/// Deterministic AI content — used only because the real AI Analysis API
/// does not exist yet (see AI_ANALYSIS_API_REQUIREMENTS.md). This is a
/// UI-development aid, **not** production content, and — critically — it
/// never invents a score, accuracy, or count: every number this class
/// generates comes from [_performanceRepository] (which, in mock mode, is
/// backed by PerformanceMockDataSource's own internally-consistent fixture —
/// see that class's doc comment), so the numbers shown here always agree
/// with what the Performance screens already show for the same data. The
/// only thing this class originates is *phrasing* — plain template
/// sentences selected by simple, documented rules (accuracy vs.
/// [TopicPerformance.strongThreshold]/[TopicPerformance.
/// needsPracticeThreshold], recent-vs-earlier attempt comparison, etc.),
/// mirroring the "deterministic aggregation, LLM only phrases" split
/// ARCHITECTURE.md §17.2 requires of the real backend.
///
/// Selected automatically when `AppConfig.isAiAnalysisApiAvailable` is
/// `false` (the default) — see ai_analysis_data_source.dart.
class AiAnalysisMockDataSource implements AiAnalysisDataSource {
  AiAnalysisMockDataSource(this._performanceRepository);

  final PerformanceRepository _performanceRepository;

  static const _artificialDelay = Duration(milliseconds: 500);

  @override
  Future<AiAnalysisModel> getOverallAnalysis(
    PerformanceFilter filter, {
    required String languageCode,
  }) async {
    await Future<void>.delayed(_artificialDelay);

    final overview = _unwrap(
      await _performanceRepository.getOverview(filter: filter),
    );
    if (overview.totalAttempts == 0) {
      return _insufficientData(AiAnalysisScope.overall, languageCode);
    }

    final topics = _unwrap(
      await _performanceRepository.getTopicPerformance(filter: filter),
    );
    final attemptsPage = _unwrap(
      await _performanceRepository.getAttempts(filter: filter, limit: 20),
    );
    final attempts = attemptsPage.items;

    final strong = topics.where((t) => t.isStrong).toList();
    final weak = topics.where((t) => t.needsPractice).toList();

    return AiAnalysisModel(
      metadata: AiAnalysisMetadataModel(
        scope: AiAnalysisScope.overall,
        status: AiAnalysisStatus.ready,
        generatedAt: DateTime.now(),
        basedOnAttemptCount: overview.totalAttempts,
      ),
      overallSummary: _overallSummary(overview, strong, weak, languageCode),
      strengths: strong.map((t) => _strengthInsight(t, languageCode)).toList(),
      weaknesses: weak
          .map((t) => _weaknessInsight(t, overview, languageCode))
          .toList(),
      topicInsights: topics.map((t) => _topicInsight(t, languageCode)).toList(),
      recurringPatterns: _recurringPatterns(attempts, languageCode),
      recommendations: _overallRecommendations(weak, languageCode),
    );
  }

  @override
  Future<AiAnalysisModel> getTopicAnalysis(
    String topicId, {
    required String languageCode,
  }) async {
    await Future<void>.delayed(_artificialDelay);

    final topics = _unwrap(await _performanceRepository.getTopicPerformance());
    final topic = topics.firstWhere(
      (t) => t.topicId == topicId,
      orElse: () => throw StateError('Unknown mock topic: $topicId'),
    );

    return AiAnalysisModel(
      metadata: AiAnalysisMetadataModel(
        scope: AiAnalysisScope.topic,
        status: AiAnalysisStatus.ready,
        generatedAt: DateTime.now(),
        topicId: topicId,
      ),
      overallSummary: _topicSummary(topic, languageCode),
      strengths: topic.isStrong
          ? [_strengthInsight(topic, languageCode)]
          : const [],
      weaknesses: topic.needsPractice
          ? [_weaknessInsightForTopic(topic, languageCode)]
          : const [],
      topicInsights: [_topicInsight(topic, languageCode)],
      recommendations: [_topicRecommendation(topic, languageCode)],
    );
  }

  @override
  Future<AiAnalysisModel> getAttemptAnalysis(
    String attemptId, {
    required String languageCode,
  }) async {
    await Future<void>.delayed(_artificialDelay);

    final details = _unwrap(
      await _performanceRepository.getAttemptDetails(attemptId),
    );

    return AiAnalysisModel(
      metadata: AiAnalysisMetadataModel(
        scope: AiAnalysisScope.attempt,
        status: AiAnalysisStatus.ready,
        generatedAt: DateTime.now(),
        attemptId: attemptId,
      ),
      overallSummary: _attemptSummary(details, languageCode),
      // An exam spans several topics (from its post-submission breakdown);
      // a study session has exactly one.
      strengths: details.topics
          .where((t) => t.isStrong)
          .map((t) => _strengthInsight(t, languageCode))
          .toList(),
      weaknesses: details.topics
          .where((t) => t.needsPractice)
          .map((t) => _weaknessInsightForTopic(t, languageCode))
          .toList(),
      topicInsights: details.topics
          .map((t) => _topicInsight(t, languageCode))
          .toList(),
      recurringPatterns: _attemptPatterns(details, languageCode),
      recommendations: _attemptRecommendations(details, languageCode),
    );
  }

  // ---------------------------------------------------------------------
  // Overall scope
  // ---------------------------------------------------------------------

  String _overallSummary(
    PerformanceOverview overview,
    List<TopicPerformance> strong,
    List<TopicPerformance> weak,
    String languageCode,
  ) {
    final accuracy = overview.overallAccuracyPercent.round();
    final buffer = StringBuffer()
      ..write(
        _t(
          languageCode,
          en:
              'Your recent practice across ${overview.totalAttempts} attempts '
              'shows an overall accuracy of $accuracy%. ',
          ar:
              'يُظهر تدريبك الأخير عبر ${overview.totalAttempts} محاولة دقة '
              'إجمالية تبلغ $accuracy%. ',
        ),
      );

    if (strong.isNotEmpty) {
      final names = _joinNames(strong.map((t) => t.topicName), languageCode);
      buffer.write(
        _t(
          languageCode,
          en: 'Performance is stronger in $names. ',
          ar: 'أداؤك أقوى في $names. ',
        ),
      );
    }

    if (weak.isNotEmpty) {
      final names = _joinNames(weak.map((t) => t.topicName), languageCode);
      buffer.write(
        _t(
          languageCode,
          en:
              'Consider reviewing $names before attempting another full '
              'simulation.',
          ar: 'يُنصح بمراجعة $names قبل خوض محاكاة اختبار كاملة أخرى.',
        ),
      );
    } else {
      buffer.write(
        _t(
          languageCode,
          en: 'Keep practicing consistently across topics to maintain this pace.',
          ar: 'واصل التدرب بانتظام على جميع الموضوعات للحفاظ على هذا المستوى.',
        ),
      );
    }

    return buffer.toString().trim();
  }

  List<AiRecommendationModel> _overallRecommendations(
    List<TopicPerformance> weak,
    String languageCode,
  ) {
    if (weak.isEmpty) {
      return [
        AiRecommendationModel(
          text: _t(
            languageCode,
            en:
                'Keep up your current study routine and revisit Attempt '
                'History periodically to track your progress.',
            ar: 'واصل روتين دراستك الحالي وراجع سجل المحاولات بشكل دوري لتتبع تقدمك.',
          ),
        ),
      ];
    }
    return weak
        .take(2)
        .map(
          (t) => AiRecommendationModel(
            text: _t(
              languageCode,
              en:
                  'Review the ${t.topicName} sub-units, then complete a '
                  'focused Study Session before returning to Simulation '
                  'mode.',
              ar:
                  'راجع الوحدات الفرعية لموضوع ${t.topicName}، ثم أكمل جلسة '
                  'دراسة مركزة قبل العودة إلى وضع المحاكاة.',
            ),
            topicId: t.topicId,
            topicName: t.topicName,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------
  // Topic scope
  // ---------------------------------------------------------------------

  String _topicSummary(TopicPerformance topic, String languageCode) {
    final accuracy = topic.accuracyPercent.round();
    if (topic.needsPractice) {
      return _t(
        languageCode,
        en:
            'Your performance in ${topic.topicName} shows room for '
            'improvement, at $accuracy% accuracy across ${topic.answered} '
            'answered questions.',
        ar:
            'يُظهر أداؤك في ${topic.topicName} مجالًا للتحسن، بدقة $accuracy% '
            'من أصل ${topic.answered} سؤالًا تمت الإجابة عنها.',
      );
    }
    if (topic.isStrong) {
      return _t(
        languageCode,
        en:
            'Your performance in ${topic.topicName} is strong, at $accuracy% '
            'accuracy across ${topic.answered} answered questions.',
        ar:
            'أداؤك في ${topic.topicName} قوي، بدقة $accuracy% من أصل '
            '${topic.answered} سؤالًا تمت الإجابة عنها.',
      );
    }
    return _t(
      languageCode,
      en:
          'Your performance in ${topic.topicName} is steady, at $accuracy% '
          'accuracy across ${topic.answered} answered questions.',
      ar:
          'أداؤك في ${topic.topicName} مستقر، بدقة $accuracy% من أصل '
          '${topic.answered} سؤالًا تمت الإجابة عنها.',
    );
  }

  AiRecommendationModel _topicRecommendation(
    TopicPerformance topic,
    String languageCode,
  ) {
    return AiRecommendationModel(
      text: topic.needsPractice
          ? _t(
              languageCode,
              en:
                  'Review the related sub-units for ${topic.topicName}, then '
                  'complete a focused Study Session before returning to '
                  'Simulation mode.',
              ar:
                  'راجع الوحدات الفرعية المرتبطة بـ ${topic.topicName}، ثم '
                  'أكمل جلسة دراسة مركزة قبل العودة إلى وضع المحاكاة.',
            )
          : _t(
              languageCode,
              en:
                  'Continue reinforcing ${topic.topicName} periodically to '
                  'maintain your accuracy.',
              ar: 'واصل تعزيز ${topic.topicName} بشكل دوري للحفاظ على دقتك.',
            ),
      topicId: topic.topicId,
      topicName: topic.topicName,
    );
  }

  // ---------------------------------------------------------------------
  // Attempt scope
  // ---------------------------------------------------------------------

  String _attemptSummary(AttemptDetails details, String languageCode) {
    final summary = details.summary;
    final accuracy = summary.accuracyPercent.round();
    final typeLabel = _t(
      languageCode,
      en: summary.type == AttemptType.studySession
          ? 'Study Session'
          : 'Exam Simulation',
      ar: summary.type == AttemptType.studySession
          ? 'جلسة دراسة'
          : 'محاكاة اختبار',
    );
    return _t(
      languageCode,
      en:
          'This $typeLabel attempt on ${summary.contentLabel} finished at '
          '$accuracy% accuracy across ${summary.answered} answered questions.',
      ar:
          'انتهت محاولة $typeLabel هذه في ${summary.contentLabel} بدقة '
          '$accuracy% من أصل ${summary.answered} سؤالًا تمت الإجابة عنها.',
    );
  }

  List<AiInsightModel> _attemptPatterns(
    AttemptDetails details,
    String languageCode,
  ) {
    final patterns = <AiInsightModel>[];
    final avgSeconds = details.averageTimePerQuestion.inSeconds;

    if (avgSeconds > 90) {
      patterns.add(
        AiInsightModel(
          kind: _patternKind,
          text: _t(
            languageCode,
            en:
                'You spent more time per question than typical practice '
                'pace, which may indicate some concepts needed extra '
                'thought.',
            ar:
                'أمضيت وقتًا أطول لكل سؤال مقارنة بوتيرة التدريب المعتادة، ما '
                'قد يشير إلى أن بعض المفاهيم احتاجت وقتًا إضافيًا للتفكير.',
          ),
        ),
      );
    } else if (avgSeconds > 0 && avgSeconds < 20) {
      patterns.add(
        AiInsightModel(
          kind: _patternKind,
          text: _t(
            languageCode,
            en:
                'Your pace was fast — it may be worth double-checking the '
                'questions you missed for rushed mistakes.',
            ar:
                'كانت وتيرتك سريعة — قد يكون من المفيد إعادة التحقق من '
                'الأسئلة الخاطئة لتفادي الأخطاء الناتجة عن التسرع.',
          ),
        ),
      );
    }

    if (details.unanswered > 0) {
      patterns.add(
        AiInsightModel(
          kind: _patternKind,
          text: _t(
            languageCode,
            en:
                '${details.unanswered} question(s) were left unanswered, '
                'which counts against your score — under timed conditions, '
                'answering every question (even with a best guess) protects '
                'your score.',
            ar:
                'تُركت ${details.unanswered} من الأسئلة دون إجابة، وهذا يُحتسب '
                'ضد نتيجتك — في ظروف الوقت المحدد، تحمي الإجابة عن كل سؤال '
                '(ولو بأفضل تخمين) نتيجتك.',
          ),
        ),
      );
    }

    if (details.wrong > 0) {
      patterns.add(
        AiInsightModel(
          kind: _patternKind,
          text: _t(
            languageCode,
            en:
                '${details.wrong} of your answers on this attempt were '
                'incorrect — reviewing them can reveal a specific pattern '
                'worth addressing.',
            ar:
                'كانت ${details.wrong} من إجاباتك في هذه المحاولة خاطئة — قد '
                'تكشف مراجعتها عن نمط محدد يستحق المعالجة.',
          ),
        ),
      );
    }

    return patterns;
  }

  List<AiRecommendationModel> _attemptRecommendations(
    AttemptDetails details,
    String languageCode,
  ) {
    final weakTopics = details.topics.where((t) => t.needsPractice).toList();
    if (weakTopics.isNotEmpty) {
      final topic = weakTopics.first;
      return [
        AiRecommendationModel(
          text: _t(
            languageCode,
            en:
                'Revisit ${topic.topicName} with a focused Study Session '
                'before your next attempt.',
            ar: 'راجع ${topic.topicName} من خلال جلسة دراسة مركزة قبل محاولتك التالية.',
          ),
          topicId: topic.topicId,
          topicName: topic.topicName,
        ),
      ];
    }
    if (details.wrong > 0) {
      return [
        AiRecommendationModel(
          text: _t(
            languageCode,
            en: 'Review the answers you missed on this attempt to understand what went wrong.',
            ar: 'راجع الإجابات التي أخطأت فيها في هذه المحاولة لفهم سبب الخطأ.',
          ),
        ),
      ];
    }
    return [
      AiRecommendationModel(
        text: _t(
          languageCode,
          en: 'Strong result — keep this pace and consider a slightly harder topic next.',
          ar: 'نتيجة قوية — حافظ على هذه الوتيرة وفكر في موضوع أصعب قليلًا في المرة القادمة.',
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------
  // Shared building blocks
  // ---------------------------------------------------------------------

  AiInsightModel _strengthInsight(TopicPerformance topic, String languageCode) {
    final accuracy = topic.accuracyPercent.round();
    return AiInsightModel(
      kind: _strengthKind,
      text: _t(
        languageCode,
        en:
            'Your recent accuracy in ${topic.topicName} has been relatively '
            'consistent, at $accuracy% across ${topic.answered} answered '
            'questions.',
        ar:
            'دقتك الأخيرة في ${topic.topicName} كانت ثابتة نسبيًا، بنسبة '
            '$accuracy% من أصل ${topic.answered} سؤالًا تمت الإجابة عنها.',
      ),
      topicId: topic.topicId,
      topicName: topic.topicName,
      supportingMetricPercent: topic.accuracyPercent,
    );
  }

  AiInsightModel _weaknessInsight(
    TopicPerformance topic,
    PerformanceOverview overview,
    String languageCode,
  ) {
    final accuracy = topic.accuracyPercent.round();
    final overallAccuracy = overview.overallAccuracyPercent.round();
    return AiInsightModel(
      kind: _weaknessKind,
      text: _t(
        languageCode,
        en:
            '${topic.topicName} appears to require additional review — '
            'recent accuracy is $accuracy% across ${topic.answered} answered '
            'questions, below your overall accuracy of $overallAccuracy%.',
        ar:
            'يبدو أن ${topic.topicName} يحتاج إلى مراجعة إضافية — الدقة '
            'الأخيرة $accuracy% من أصل ${topic.answered} سؤالًا، وهي أقل من '
            'دقتك الإجمالية البالغة $overallAccuracy%.',
      ),
      topicId: topic.topicId,
      topicName: topic.topicName,
      supportingMetricPercent: topic.accuracyPercent,
    );
  }

  AiInsightModel _weaknessInsightForTopic(
    TopicPerformance topic,
    String languageCode,
  ) {
    final accuracy = topic.accuracyPercent.round();
    return AiInsightModel(
      kind: _weaknessKind,
      text: _t(
        languageCode,
        en:
            'Your accuracy in ${topic.topicName} is $accuracy% across '
            '${topic.answered} answered questions — lower than several of '
            'your other topics.',
        ar:
            'دقتك في ${topic.topicName} هي $accuracy% من أصل ${topic.answered} '
            'سؤالًا — أقل من العديد من موضوعاتك الأخرى.',
      ),
      topicId: topic.topicId,
      topicName: topic.topicName,
      supportingMetricPercent: topic.accuracyPercent,
    );
  }

  AiTopicInsightModel _topicInsight(
    TopicPerformance topic,
    String languageCode,
  ) {
    final interpretation = topic.needsPractice
        ? _t(
            languageCode,
            en: 'Your accuracy here is lower than your recent performance in several other topics.',
            ar: 'دقتك هنا أقل من أدائك الأخير في عدة موضوعات أخرى.',
          )
        : topic.isStrong
        ? _t(
            languageCode,
            en: 'Your recent results suggest a solid grasp of this topic.',
            ar: 'تشير نتائجك الأخيرة إلى إتقان جيد لهذا الموضوع.',
          )
        : _t(
            languageCode,
            en: 'Your recent performance here is steady, without a clear strength or weakness yet.',
            ar: 'أداؤك هنا مستقر حاليًا، دون وجود نقطة قوة أو ضعف واضحة بعد.',
          );

    final recommendedAction = topic.needsPractice
        ? _t(
            languageCode,
            en: 'Review the related sub-units, then complete a focused Study Session on ${topic.topicName}.',
            ar: 'راجع الوحدات الفرعية ذات الصلة، ثم أكمل جلسة دراسة مركزة على ${topic.topicName}.',
          )
        : _t(
            languageCode,
            en: 'Keep reinforcing ${topic.topicName} with occasional practice to maintain your accuracy.',
            ar: 'واصل تعزيز ${topic.topicName} بتدريب دوري للحفاظ على دقتك.',
          );

    return AiTopicInsightModel(
      topicId: topic.topicId,
      topicName: topic.topicName,
      accuracyPercent: topic.accuracyPercent,
      answered: topic.answered,
      correct: topic.correct,
      interpretation: interpretation,
      recommendedAction: recommendedAction,
    );
  }

  List<AiInsightModel> _recurringPatterns(
    List<AttemptSummary> attempts,
    String languageCode,
  ) {
    if (attempts.length < 2) return const [];
    final patterns = <AiInsightModel>[];

    // `attempts` is most-recent-first (see PerformanceRepository.getAttempts),
    // so the first half is "recent" and the rest is "earlier" — a simple,
    // documented split, not a statistical trend model.
    final half = (attempts.length / 2).ceil();
    final recent = attempts.take(half).toList();
    final earlier = attempts.skip(half).toList();

    if (earlier.isNotEmpty) {
      final recentAvg =
          recent.map((a) => a.accuracyPercent).reduce((a, b) => a + b) /
          recent.length;
      final earlierAvg =
          earlier.map((a) => a.accuracyPercent).reduce((a, b) => a + b) /
          earlier.length;
      final delta = (recentAvg - earlierAvg).round();

      if (delta >= 5) {
        patterns.add(
          AiInsightModel(
            kind: _patternKind,
            text: _t(
              languageCode,
              en:
                  'Your recent attempts show improved accuracy compared to '
                  'earlier ones — up about $delta percentage points.',
              ar:
                  'تُظهر محاولاتك الأخيرة تحسنًا في الدقة مقارنة بالمحاولات '
                  'السابقة — بزيادة نحو $delta نقطة مئوية.',
            ),
          ),
        );
      } else if (delta <= -5) {
        patterns.add(
          AiInsightModel(
            kind: _patternKind,
            text: _t(
              languageCode,
              en:
                  'Your recent attempts show lower accuracy than earlier '
                  'ones — a drop of about ${-delta} percentage points, which '
                  'may be worth a closer look.',
              ar:
                  'تُظهر محاولاتك الأخيرة دقة أقل من المحاولات السابقة — '
                  'بانخفاض نحو ${-delta} نقطة مئوية، وقد يستحق ذلك مزيدًا من '
                  'الاهتمام.',
            ),
          ),
        );
      }
    }

    final withUnanswered = attempts.where((a) => a.answered < a.totalQuestions);
    if (withUnanswered.isNotEmpty) {
      patterns.add(
        AiInsightModel(
          kind: _patternKind,
          text: _t(
            languageCode,
            en:
                'Some attempts include unanswered questions, which lowers '
                'your overall score even when accuracy on answered '
                'questions is high.',
            ar:
                'تتضمن بعض المحاولات أسئلة بلا إجابة، ما يخفض نتيجتك '
                'الإجمالية حتى عندما تكون دقة الأسئلة المجاب عنها مرتفعة.',
          ),
        ),
      );
    }

    return patterns;
  }

  AiAnalysisModel _insufficientData(
    AiAnalysisScope scope,
    String languageCode,
  ) {
    return AiAnalysisModel(
      metadata: AiAnalysisMetadataModel(
        scope: scope,
        status: AiAnalysisStatus.insufficientData,
        generatedAt: DateTime.now(),
        basedOnAttemptCount: 0,
      ),
      overallSummary: _t(
        languageCode,
        en: 'Complete a Study Session or Exam Simulation to unlock personalized AI insights.',
        ar: 'أكمل جلسة دراسة أو محاكاة اختبار لفتح رؤى ذكاء اصطناعي مخصصة لك.',
      ),
    );
  }
}

/// `PerformanceRepository` returns `Result`, not a thrown exception — this
/// unwraps it the same way performance_providers.dart's own `_unwrap` does,
/// so a (theoretical, since the mock repository never actually fails)
/// failure surfaces as a thrown [AppFailure] that AiAnalysisRepositoryImpl's
/// `_guard` catch-all turns into `UnknownFailure`, exactly like an unknown
/// mock id does elsewhere in this codebase (see PerformanceMockDataSource.
/// getAttemptDetails).
T _unwrap<T>(Result<T> result) {
  return result.when(
    success: (value) => value,
    failure: (failure) => throw failure,
  );
}

/// Picks between the two hand-written copies for this mock's deterministic
/// bilingual content (see this class's doc comment on why this is not a
/// runtime translation) — every piece of AI-generated text in this file
/// goes through this rather than the app's ARB catalogs, because it is
/// generated in the data layer, with no `BuildContext`/`AppLocalizations`
/// available (see presentation/providers/ai_analysis_language_provider.dart
/// for how `languageCode` reaches here).
String _t(String languageCode, {required String en, required String ar}) {
  return languageCode == 'ar' ? ar : en;
}

/// Joins topic names for a sentence like "stronger in X, Y, and Z" — plain
/// comma-separated (with the Arabic comma glyph for `ar`) rather than a
/// full ICU list formatter, since this app has no other precedent for
/// localized list joining and the mock topic set is always small (2-4
/// items).
String _joinNames(Iterable<String> names, String languageCode) {
  final separator = languageCode == 'ar' ? '، ' : ', ';
  return names.join(separator);
}
