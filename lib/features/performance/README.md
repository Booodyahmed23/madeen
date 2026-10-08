# performance

Results & Performance Analytics feature (Phase 6) — a read-only summary of
what a student's Study Session and Exam Simulation attempts add up to:
overall accuracy/score, per-topic strengths/weaknesses, and attempt
history. See `PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md` at the `mobile/`
root for the proposed backend contract; that backend module does not exist
yet, so this feature runs on a deterministic local fixture by default (see
`AppConfig.isPerformanceApiAvailable`).

## API mode (`PERFORMANCE_API_AVAILABLE`)

`PerformanceRemoteDataSource` reads `/results/*` (docs/MOBILE_API_CONTRACT.md
§A5):

- **Overview** — `GET /results/overview`; `overallScorePercent =
  scorePercent ?? 0`, `averageTimePerQuestion = avgTimeSeconds ?? 0`.
  Best/weak topics still come from topic performance.
- **Topics** — `GET /results/performance/topics`; `total` is the answered
  count (only revealed answers are counted), so `answered = total` and
  `questionsAttempted` falls back to `total`.
- **History** — `GET /results/history` paged by `page`/`limit`. Rows that
  aren't finalised (`finalizedAt: null`) are left out: Home's "Continue"
  cards offer those. The label is the attempt's topics resolved through
  the curriculum ("Budgeting +2"), falling back to the attempt type.
- **Details** — the attempt itself: `GET /study/sessions/:id`, or on a 404
  `GET /exams/attempts/:id` (ids are UUIDs, so they can't collide), with
  the study/exam result derivations and per-topic grouping.
- The `type` filter is `STUDY` / `EXAM`; "all" sends none.

In this mode nothing is recorded on the device — the server already has
every attempt.

## Why this is its own feature, not part of Study Session or Exam Simulation

This module **never scores an attempt or owns a state machine** — Study
Session and Exam Simulation each remain the sole authority over their own
results (`SessionResult`, `ExamResult`), matching `docs/ARCHITECTURE.md`
§3's module boundary rule that a module never reaches into another's
logic. Performance Analytics only *reads* — either from its own backend
endpoints (once they exist) or, today, from its own mock fixture — and
aggregates.

Concretely, this means:

- No code here imports `StudySessionNotifier`/`ExamNotifier`, watches their
  providers, or mutates their state. The adapter functions in
  `data/mappers/` are the *only* touch points, and they are pure functions
  over already-public result/config entities — not a runtime dependency on
  either feature's execution. The runtime connection lives outside this
  feature, in `app/practice_attempt_recorder.dart` (see below).
- The "Review answers" button on Attempt Details pushes to Study
  Session's/Exam Simulation's own existing routes (`AppRoutes.
  studySessionReview` / `AppRoutes.examPostReview`) rather than
  duplicating a review UI — see `PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md`'s
  "Known limitations" for what that button can and can't show for an
  arbitrary historical attempt today.
- `TopicPerformance` rows only ever come from Study Session data — Exam
  Simulation questions carry no topic/curriculum context by design (see
  `EXAM_SIMULATION_API_REQUIREMENTS.md`), so there is nothing to aggregate
  per-topic from an exam attempt. This is enforced in the mock data source
  and documented in the proposed API contract, not assumed silently by the
  UI.

## Two accuracy-shaped numbers, on purpose

`scorePercent` (Correct / Total Questions × 100, unanswered counts against
it) and `accuracyPercent` (Correct / Answered × 100) are both present on
`AttemptSummary` and shown side by side on Attempt Details — see
`PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md`'s "The one accuracy formula"
section for why these are deliberately different numbers, not a
formula that silently changes between screens.

## The connected practice loop (Phase 13, mock mode only)

While `AppConfig.isPerformanceApiAvailable` is `false`, completed attempts
are recorded on the device so the app's core loop is real end to end:

```
StudySessionCompleted / ExamCompleted
  → app/practice_attempt_recorder.dart   (composition layer, records once)
  → data/mappers → LocalAttemptRecord     (unique local-<id>-<µs> id)
  → localAttemptsProvider                 (per-user, SharedPreferences)
  → performanceDataSourceProvider         (rebuilds: fixtures + local)
  → repository → Performance / AI Analysis providers → Home
```

- **Per user:** `performance.local_attempts.v1.<userId>`, newest first,
  capped at 500; logout hides it, the same user gets it back, another user
  never sees it. Corrupt data reads as empty. In-progress sessions are never
  stored.
- **Merge:** fixtures are untouched — with no local attempts every number
  is identical to the fixture-only output. Topics are aggregated by
  `topicId` (summed counts, average time weighted by questions answered);
  exam records never create topic rows.
- **API mode:** nothing is recorded and local records are never merged
  (`performanceApiAvailableProvider`, tested), so no attempt can be
  double-counted once the backend is the source of truth.
- `PerformanceRepository` stays read-only — there is no `recordAttempt`.

## Not in this phase

- **AI-powered analysis** (weakness explanations, recommendations,
  narrative summaries) — a separate, later phase per `docs/ARCHITECTURE.md`
  §17.2. `TopicPerformance.isStrong`/`needsPractice` are a simple,
  documented accuracy threshold, not a weighting algorithm, and must not be
  extended into one here.
- **Recommendation/"what to practice next" logic.**
- Any backend write path — this feature has no submit/create endpoint of its
  own (the mock-mode local record above is device-only).
