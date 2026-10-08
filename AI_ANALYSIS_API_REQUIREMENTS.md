# AI Analysis API — required backend contract (not yet implemented)

**Status as of Phase 7 (mobile): these endpoints do not exist on the
backend.** Verified by inspection — `backend/src/modules/` currently
contains only `identity` and `notification`; there is no AIAnalysis module
(see `docs/ARCHITECTURE.md` §3/§17.2 for where it's planned). This document
is the mobile app's proposed contract, written so whoever implements the
backend module can do so without reading Flutter code, and so both sides
agree on shapes ahead of time. It mirrors the style of `docs/API_AUTH.md`
and `mobile/PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md`.

Until this exists, the mobile app runs entirely on a deterministic local
generator — see "Current mobile-side status" at the bottom. **Do not treat
this document as an existing API** — no backend code has been written to
match it, and the exact endpoint paths below are a proposal, not a
confirmed contract.

**PROPOSED / BACKEND DEPENDENCY — every endpoint in this document.**

## Why this must not fabricate anything

Per `docs/ARCHITECTURE.md` §17.2, AI Exam Analysis "must be architected as a
data pipeline, not a chatbot prompt": a deterministic aggregation stage
(reading `SessionAttempt`/`SimulationQuestion` joined to `Curriculum` — the
same source `PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md`'s endpoints already
aggregate) computes the actual numbers first; only the *phrasing* of
strengths/weaknesses/recommendations is the LLM's job, and every claim the
LLM produces must be validated against the input numbers before being
returned (§17.2's "a lint check that every topic named in `weaknesses[]`
exists in the aggregation with the stated accuracy"). Concretely, every
endpoint below:

- Must source every number (`accuracyPercent`, `answered`, `correct`,
  `supportingMetricPercent`, `basedOnAttemptCount`) from the same
  aggregation `PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md` already defines —
  never a second, independent calculation that could drift from what the
  Performance screens show for the same student.
- Must run generation as an async job (queue-driven, per §17.2 point 4) once
  a real LLM call is involved, not inline in the request — the response
  shapes below are what the client reads once generation has completed;
  how the backend gets there (synchronous for a fast/cached case, or a
  poll/webhook for a fresh generation) is a backend implementation decision
  out of scope for this client-facing contract, as long as the response
  shape below is what's eventually returned.
- Must never claim a diagnosis the data doesn't support (see the phase
  brief's GOOD/BAD phrasing examples, mirrored in this feature's README).

## Endpoints

All under the existing `/api/v1` prefix, alongside `/auth/*`, `/users/*`,
`/performance/*`, and the other proposed feature contracts in this
directory.

**Auth:** every endpoint below requires the same authenticated-user access
as the rest of the app (bearer access token, per `docs/API_AUTH.md`). Like
every Performance Analytics endpoint, there is no `userId` parameter
anywhere in this contract — every response is implicitly scoped to the
authenticated caller.

**Locale:** every endpoint below accepts an optional `locale` query
parameter (`en` | `ar`, default `en`) and returns every free-text field
already phrased in that language — this is *not* a bilingual payload (no
`{en, ar}` pairs on the wire); the client sends the student's current
effective UI language (see `aiAnalysisLanguageProvider`) and the backend
(or the LLM prompt template) is responsible for generating that language's
copy. This differs from `docs/ARCHITECTURE.md` §19's `_i18n: {en, ar}`
column convention for *authored* content (curriculum/question text) — AI
copy is generated per-request, not authored once and stored in both
languages.

### `GET /api/v1/ai-analysis/overview`

**Query parameters:** `attemptType` — optional, one of `STUDY_SESSION` /
`EXAM_SIMULATION`; omitted means both (same semantics as
`GET /performance/overview`). `locale` — see above.

**Response `200`:**

```json
{
  "metadata": {
    "scope": "OVERALL",
    "status": "READY",
    "generatedAt": "2026-09-16T09:05:00.000Z",
    "basedOnAttemptCount": 6
  },
  "overallSummary": "Your recent practice across 6 attempts shows an overall accuracy of 77%. Performance is stronger in Budgeting. Consider reviewing Variance Analysis before attempting another full simulation.",
  "strengths": [
    {
      "kind": "STRENGTH",
      "text": "Your recent accuracy in Budgeting has been relatively consistent, at 90% across 20 answered questions.",
      "topicId": "topic-budgeting",
      "topicName": "Budgeting",
      "supportingMetricPercent": 90.0
    }
  ],
  "weaknesses": [
    {
      "kind": "WEAKNESS",
      "text": "Variance Analysis appears to require additional review — recent accuracy is 55% across 20 answered questions, below your overall accuracy of 77%.",
      "topicId": "topic-variance-analysis",
      "topicName": "Variance Analysis",
      "supportingMetricPercent": 55.0
    }
  ],
  "topicInsights": [
    {
      "topicId": "topic-budgeting",
      "topicName": "Budgeting",
      "accuracyPercent": 90.0,
      "answered": 20,
      "correct": 18,
      "interpretation": "Your recent results suggest a solid grasp of this topic.",
      "recommendedAction": "Keep reinforcing Budgeting with occasional practice to maintain your accuracy."
    }
  ],
  "recurringPatterns": [
    {
      "kind": "PATTERN",
      "text": "Some attempts include unanswered questions, which lowers your overall score even when accuracy on answered questions is high."
    }
  ],
  "recommendations": [
    {
      "text": "Review the Variance Analysis sub-units, then complete a focused Study Session before returning to Simulation mode.",
      "topicId": "topic-variance-analysis",
      "topicName": "Variance Analysis"
    }
  ]
}
```

`status: "INSUFFICIENT_DATA"` (with every list empty and `overallSummary`
holding the localized "complete a Study Session..." explanation) is the
valid response for a student who hasn't completed anything yet — not a
`404`, mirroring `GET /performance/overview`'s own `totalAttempts: 0` rule.

### `GET /api/v1/ai-analysis/topics/:topicId`

**Query parameters:** `locale` — see above.

**Response `200`:** same envelope as above with `metadata.scope: "TOPIC"`,
`metadata.topicId` set, `metadata.basedOnAttemptCount` omitted (the topic's
own `answered`/`correct` on `topicInsights[0]` is the evidence for this
scope — see this feature's README on why an attempt count would be
redundant here), `topicInsights` containing exactly one entry, and
`strengths`/`weaknesses` containing at most one entry (this same topic,
present only if it crosses the strong/needs-practice threshold).

`404` for an unknown or inaccessible `topicId` — same anti-enumeration
posture as `GET /performance/attempts/:attemptId`.

### `GET /api/v1/ai-analysis/attempts/:attemptId`

**Query parameters:** `locale` — see above.

**Response `200`:** same envelope with `metadata.scope: "ATTEMPT"`,
`metadata.attemptId` set, `metadata.basedOnAttemptCount` omitted,
`topicInsights` mirroring that attempt's own topic breakdown (`[]` for an
Exam Simulation attempt or a Study Session attempt with none yet — same
rule as `AttemptDetails.topics`), and `strengths`/`weaknesses` typically
empty (a single attempt rarely has enough data to call something a durable
strength/weakness — that judgment belongs to the overall/topic scopes,
which aggregate across attempts).

`404` for an unknown or inaccessible `attemptId` — same anti-enumeration
posture as `GET /performance/attempts/:attemptId`.

## Shared field notes

- `metadata.generatedAt` — ISO-8601 UTC. A real backend should persist this
  alongside the report (`AnalysisReport.generated_at` per
  `docs/ARCHITECTURE.md` §6.2) rather than always returning "now"; the mock
  client-side generator returns fetch time since it has nothing to persist.
- `supportingMetricPercent` / `topicInsights[].accuracyPercent` /
  `.answered` / `.correct` — must equal what the corresponding
  `GET /performance/*` endpoint would return for the same topic/attempt at
  generation time. A lint/validation step on the backend (§17.2) should
  reject a generation whose LLM output names a number that doesn't match
  the aggregation it was given.
- `kind` — `STRENGTH` | `WEAKNESS` | `PATTERN`. `PATTERN` is used for
  `recurringPatterns` entries and is the only kind that may omit
  `topicId`/`topicName` (a cross-topic observation, e.g. about pacing or
  unanswered questions).

## Common behavior expected of every endpoint above

- **Errors:** the standard envelope from `docs/API_AUTH.md`
  (`{statusCode, message, error, path, timestamp, requestId}`). `401` per
  the normal auth rules, `404` for an unknown/inaccessible `topicId`/
  `attemptId`, `500` on server error, and (recommended, not required this
  phase) `429` if a per-user AI generation rate limit is added — mirrors
  `docs/ARCHITECTURE.md` §17.1's AI Tutor cost-control concern, though
  Analysis is read/cached rather than a live chat call.
- **Read-only:** none of these endpoints accept a body or mutate anything.
- **This is not the Performance Analytics contract.** Nothing here should
  be reused or overloaded for it, and vice versa — see this feature's
  README on why the dependency only runs *from* AI Analysis *into*
  Performance, never the other way.

## Current mobile-side status

The mobile app already has the full client-side abstraction ready for this
contract:

- `lib/features/ai_analysis/domain/` — `AiAnalysis`, `AiInsight`,
  `AiTopicInsight`, `AiRecommendation`, `AiAnalysisMetadata` entities and
  the `AiAnalysisRepository` interface.
- `lib/features/ai_analysis/data/datasources/ai_analysis_remote_data_source.dart`
  — implements the calls above exactly as documented. **Not yet
  integration-tested against a real server** — there is nothing to
  integration-test against.
- `lib/features/ai_analysis/data/datasources/ai_analysis_mock_data_source.dart`
  — a deterministic generator (not a fixed fixture like Performance's mock,
  since AI Analysis has no data of its own to fix — instead it reads
  Performance's live mock data through `PerformanceRepository` and applies
  simple, documented phrasing rules) — used instead of the real API until
  it exists. **This generated content is a UI-development aid only — it is
  not, and must never be mistaken for, real AI-generated analysis.**

**Switching to the real backend once it ships:** set
`AI_ANALYSIS_API_AVAILABLE=true` in `mobile/env/{dev,staging,prod}.json`
(per environment, as each is ready) — see
`AppConfig.isAiAnalysisApiAvailable` in `lib/core/config/app_config.dart`.
No other mobile code needs to change. This flag is independent of
`PERFORMANCE_API_AVAILABLE` — the mock AI datasource reads through
`performanceRepositoryProvider` regardless of which Performance datasource
backs it, so "real Performance data, mock AI analysis" is a valid
intermediate deployment state. If the actual response shape ends up
differing from this document, only `ai_analysis_remote_data_source.dart`
and the `data/models/*.dart` files need updating — the domain layer, state
management, and every screen are unaffected.
