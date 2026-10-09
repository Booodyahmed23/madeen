# ai_analysis

AI-Powered Performance Analysis (Phase 7) — an explanatory/recommendation
layer over the Performance Analytics feature: it never scores an attempt,
never computes an accuracy/score/count of its own, and never invents a
factual number. See `AI_ANALYSIS_API_REQUIREMENTS.md` at the `mobile/` root
for the proposed backend contract; that backend module (`AIAnalysis` in
`docs/ARCHITECTURE.md` §3/§17.2) does not exist yet, so this feature runs on
a deterministic generator by default (see `AppConfig.isAiAnalysisApiAvailable`)
that derives every number it mentions from the real `PerformanceRepository` —
the same repository Performance Overview/Topic Performance/Attempt History
already read.

## Why this legitimately depends on the Performance feature

Every other feature-to-feature dependency in this app is deliberately
narrow or forbidden (see `features/performance/README.md` on why Performance
never imports Study Session's/Exam Simulation's notifiers). AI Analysis is
different: per `docs/ARCHITECTURE.md` §17.2, "AI Exam Analysis" is *defined*
as a second pass over Performance's own aggregation — "the analysis itself
... is computed deterministically in application code first; the LLM's role
is presentation/prioritization framing, not the source of truth for
numbers." Concretely, this means:

- `AiAnalysisRepository` methods take a `PerformanceFilter` (imported
  directly from `features/performance/domain/entities/`, not duplicated)
  because "AI Analysis over the current attemptType scope" is the same
  scope Performance Overview already has selected.
- `AiAnalysisMockDataSource` is constructed with a `PerformanceRepository`
  (see `data/datasources/ai_analysis_data_source.dart`'s provider) and calls
  its `getOverview`/`getTopicPerformance`/`getAttempts`/`getAttemptDetails`
  methods to source every number it phrases — it never maintains its own
  copy of "what a strong topic looks like" (it reads `TopicPerformance.
  isStrong`/`needsPractice`, the same threshold Topic Performance itself
  uses) or its own fixture.
- The dependency is one-directional and through Performance's public
  domain/repository interfaces only — never a concrete data source, never a
  notifier, never internal state. `features/performance/` has zero imports
  from `features/ai_analysis/` (verify with `grep -r ai_analysis
  lib/features/performance/`).

## Why one `AiAnalysis` shape for every scope

`AiAnalysisMetadata.scope` (overall / topic / attempt / recent) is what
varies, not the entity shape — a single `AiAnalysis` (overallSummary +
strengths + weaknesses + topicInsights + recurringPatterns +
recommendations) is reused for the Overall Analysis screen, the Topic AI
Insight screen, and the Attempt AI Insight screen, with each scope simply
populating a different subset of the fields (see
`data/datasources/ai_analysis_mock_data_source.dart`). This keeps the
model "extensible for future AI capabilities" per the phase brief without a
parallel class per screen.

## AI principles this feature enforces

- Every `AiInsight`/`AiTopicInsight` carries the exact metric it's making a
  claim about (`supportingMetricPercent`, or the topic's own
  `accuracyPercent`/`answered`/`correct`) — a student can always verify a
  claim against the same numbers Topic Performance/Attempt History show.
- Copy is deliberately hedged ("your recent results suggest...", "consider
  reviewing...") rather than diagnostic ("you don't understand standard
  costing") — see `AiTopicInsight.interpretation`'s doc comment and the
  phase brief's "GOOD/BAD" examples.
- `AiAnalysisStatus.insufficientData` (zero attempts) is a valid, expected
  content state with its own localized explanation, never an error and
  never a fabricated "you're doing great!" for a student with no data.

## Not in this phase

- **A real LLM call.** `AiAnalysisRemoteDataSource` is a client-side
  abstraction for a backend endpoint that doesn't exist yet — this app never
  calls OpenAI/Gemini/Claude (or any AI provider) directly, and holds no AI
  provider credentials. See AI_ANALYSIS_API_REQUIREMENTS.md.
- **Bilingual runtime translation.** The mock's English/Arabic copy is
  hand-written and selected by `aiAnalysisLanguageProvider`'s language code
  (see that file's doc comment for why this feature — uniquely — needs a
  language code outside a `BuildContext`), never machine-translated.
- **A resume/reload capability for an arbitrary historical attempt** beyond
  what Performance's own Attempt Details already provides — Attempt AI
  Insight reads the same `AttemptDetails` Attempt Details does, with the
  same limitations (see docs/MOBILE_API_CONTRACT.md §A5).
