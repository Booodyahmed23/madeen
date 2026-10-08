# Performance Analytics API — required backend contract (not yet implemented)

**Status as of Phase 6 (mobile): these endpoints do not exist on the
backend.** Verified by inspection — `backend/src/modules/` currently
contains only `identity` and `notification`; there is no Performance/
Analytics module. This document is the mobile app's proposed contract,
written so whoever implements the backend module can do so without reading
Flutter code, and so both sides agree on shapes ahead of time. It mirrors
the style of `docs/API_AUTH.md`, `mobile/STUDY_SESSION_API_REQUIREMENTS.md`,
and `mobile/EXAM_SIMULATION_API_REQUIREMENTS.md`.

Until this exists, the mobile app runs entirely on deterministic local
sample data — see "Current mobile-side status" at the bottom. **Do not
treat this document as an existing API** — no backend code has been written
to match it, and the exact endpoint paths below are a proposal, not a
confirmed contract.

**PROPOSED / BACKEND DEPENDENCY — every endpoint in this document.**

## Why this is a separate, read-only contract

Performance Analytics never creates or scores an attempt — it only reads
and aggregates what Study Session and Exam Simulation have already
recorded. Nothing here should be merged with or reused from
`STUDY_SESSION_API_REQUIREMENTS.md` or `EXAM_SIMULATION_API_REQUIREMENTS.md`
even where shapes look similar, and this module must never become the
place attempt-scoring logic lives — that stays owned by StudySession and
Simulation respectively (see `docs/ARCHITECTURE.md` §3's module boundary
table). A real backend implementation of this module would read from
`SessionAttempt`/`SimulationQuestion` (joined to `Curriculum` for topic
names), the same way `docs/ARCHITECTURE.md` §17.2 describes the AI
Analysis aggregation stage doing — this module is that same aggregation,
exposed directly to the client, with no AI/LLM step.

**The Flutter client must never be trusted as the authority for:**

- any score, accuracy, or aggregate number shown on these screens
- another user's performance data (every endpoint below is implicitly
  scoped to the authenticated caller — there is no `userId` parameter
  anywhere in this contract, on purpose, so a client can't even attempt to
  ask for someone else's data)

## The one accuracy formula

**Accuracy = Correct / Answered × 100.** Every endpoint below that returns
an accuracy-shaped number uses this formula and no other. `scorePercent`
(on attempt-shaped responses) is a different, related number — **Correct /
Total Questions × 100** (unanswered questions count against it, matching
how `SessionResult`/`ExamResult` already compute their own score) — the two
are shown side by side on the mobile Attempt Details screen specifically so
a student can tell "70% overall" apart from "90% of what I actually
answered." A backend implementation must not silently swap one formula for
the other between endpoints.

## Endpoints

All under the existing `/api/v1` prefix, alongside `/auth/*`, `/users/*`,
and the other proposed feature contracts in this directory.

**Auth:** every endpoint below requires the same authenticated-user access
as the rest of the app (bearer access token, per `docs/API_AUTH.md`).

### `GET /api/v1/performance/overview`

**Query parameters:** `attemptType` — optional, one of `STUDY_SESSION` /
`EXAM_SIMULATION`; omitted means both.

**Response `200`:**

```json
{
  "totalAttempts": 6,
  "questionsPracticed": 205,
  "totalAnswered": 197,
  "totalCorrect": 151,
  "overallScorePercent": 73.66,
  "totalTimeSeconds": 25000,
  "averageTimePerQuestionSeconds": 121
}
```

`totalAttempts: 0` (with every count at `0`) is a valid response for a
student who hasn't completed anything yet — not a `404`; the mobile Overview
screen shows its own "No performance data yet" state for this case.

### `GET /api/v1/performance/topics`

**Query parameters:** `attemptType` — optional, same values as above. Since
Exam Simulation questions never carry topic/curriculum context (see
`EXAM_SIMULATION_API_REQUIREMENTS.md`), `attemptType=EXAM_SIMULATION`
correctly returns `[]`, not an error.

**Response `200`:**

```json
[
  {
    "topicId": "topic-budgeting",
    "topicName": "Budgeting",
    "questionsAttempted": 20,
    "answered": 20,
    "correct": 18,
    "wrong": 2,
    "averageTimePerQuestionSeconds": 60
  }
]
```

`topicId`/`topicName` may name any level of the Program → Part → Unit →
Sub-unit → Topic hierarchy the backend chooses to aggregate at — the mobile
client treats this as an opaque id/label pair and does not assume it is
specifically a `Topic` row. `averageTimePerQuestionSeconds` is nullable —
omit the field (or send `null`) when there isn't enough timing data for
that node yet; the client shows the rest of the row without it.

An empty `[]` is a valid response (no topics practiced yet); the client
shows its own "No topic performance yet" empty state.

### `GET /api/v1/performance/attempts`

Paginated Attempt History, most recent first.

**Query parameters:**

| Param | Type | Notes |
|---|---|---|
| `attemptType` | `string` | optional, `STUDY_SESSION` \| `EXAM_SIMULATION`, omitted = both |
| `limit` | `number` | optional, default `20` |
| `offset` | `number` | optional, default `0` |

**Response `200`:**

```json
{
  "items": [
    {
      "attemptId": "attempt-abc123",
      "type": "STUDY_SESSION",
      "completedAt": "2026-09-16T09:00:00.000Z",
      "contentLabel": "Budgeting",
      "totalQuestions": 20,
      "answered": 20,
      "correct": 18,
      "scorePercent": 90.0,
      "durationSeconds": 1200
    }
  ],
  "hasMore": true
}
```

`contentLabel` is a pre-resolved display string (a topic name for a Study
Session attempt, or a `"Program Part"` label such as `"CMA Part 1"` for an
Exam Simulation attempt) — the client never re-derives it from a
curriculum lookup. `hasMore` is what the client uses to decide whether to
offer "Load more"; it never infers this from `items.length == limit`.

### `GET /api/v1/performance/attempts/:attemptId`

Full detail for one attempt — `404` for an unknown or inaccessible
`attemptId` (including one that belongs to a different user — this must
never leak a `403` vs `404` distinction that would let a client
fingerprint valid ids belonging to other users; treat "not yours" and
"doesn't exist" identically, same anti-enumeration posture as
`docs/API_AUTH.md`'s login endpoint).

**Response `200`:**

```json
{
  "attemptId": "attempt-abc123",
  "type": "STUDY_SESSION",
  "completedAt": "2026-09-16T09:00:00.000Z",
  "contentLabel": "Budgeting",
  "totalQuestions": 20,
  "answered": 20,
  "correct": 18,
  "scorePercent": 90.0,
  "durationSeconds": 1200,
  "unanswered": 0,
  "wrong": 2,
  "averageTimePerQuestionSeconds": 60,
  "topics": [
    {
      "topicId": "topic-budgeting",
      "topicName": "Budgeting",
      "questionsAttempted": 20,
      "answered": 20,
      "correct": 18,
      "wrong": 2,
      "averageTimePerQuestionSeconds": 60
    }
  ]
}
```

Note the summary fields (`attemptId` through `durationSeconds`) are the
exact same shape as one item from `GET /performance/attempts`, flattened
into this same object rather than nested under a `summary` key — the
mobile model parses both with the same summary-parsing logic. `topics` is
`[]` for an Exam Simulation attempt (always) and may also be `[]` for a
Study Session attempt the backend hasn't computed a breakdown for yet —
both are valid, not an error.

## Common behavior expected of every endpoint above

- **Errors:** the standard envelope from `docs/API_AUTH.md`
  (`{statusCode, message, error, path, timestamp, requestId}`). `401` per
  the normal auth rules, `404` for an unknown/inaccessible `attemptId`,
  `500` on server error. No performance-specific error shape is needed.
- **Read-only:** none of these endpoints accept a body or mutate anything —
  this module has no write path. Attempt data is created exclusively by
  the Study Session and Exam Simulation submit endpoints in their own
  contracts.
- **This is not the Study Session or Exam Simulation contract.** Nothing
  here should be reused or overloaded for either, and vice versa.

## Known limitations of the current mobile-side integration

- **Mock-mode practice loop (Phase 13).** While
  `PERFORMANCE_API_AVAILABLE` is `false`, completed Study Sessions and Exam
  Simulations are recorded **on the device** (`LocalAttemptRecord`, one
  SharedPreferences list per signed-in user, capped at 500) by the
  app-level recorder (`lib/app/practice_attempt_recorder.dart`), and the
  mock data source merges them ahead of its fixtures. This stands in for
  what the backend's own Study Session / Exam Simulation submit endpoints
  will do; this contract stays read-only. **Once
  `PERFORMANCE_API_AVAILABLE` is `true`, nothing is recorded locally and
  local records are never merged** — the endpoints above are the only
  source of truth, so no attempt can be double-counted. Local records are
  not uploaded or migrated to the backend.
- **The "Review answers" button on Attempt Details** navigates to Study
  Session's / Exam Simulation's own existing review routes (never a
  duplicated review screen), but those routes render whatever that
  feature's own notifier currently holds, not the specific historical
  `attemptId` the student drilled into — there is no "resume/reload an old
  attempt by id" capability in either feature yet (see their own API
  requirement docs' "Known limitations"/"not yet wired" notes on
  `getAttempt`). This is most useful immediately after finishing a
  session/exam; for older history entries it still navigates safely (that
  screen shows its own graceful "nothing to review" state) but won't show
  that attempt's specific answers until a resume/reload capability exists.

## Current mobile-side status

The mobile app already has the full client-side abstraction ready for this
contract:

- `lib/features/performance/domain/` — `PerformanceOverview`,
  `TopicPerformance`, `AttemptSummary`, `AttemptDetails`,
  `AttemptHistoryPage`, `PerformanceFilter` entities and the
  `PerformanceRepository` interface.
- `lib/features/performance/data/datasources/performance_remote_data_source.dart`
  — implements the calls above exactly as documented. **Not yet
  integration-tested against a real server** — there is nothing to
  integration-test against.
- `lib/features/performance/data/datasources/performance_mock_data_source.dart`
  — a small, deterministic, internally-consistent fixture (six attempts
  mixing both types, four topics spanning strong/neutral/needs-practice
  accuracy) — used instead of the real API until it exists. **This mock
  data is a UI-development aid only — it is not, and must never be
  mistaken for, a real student's performance history.**

**Switching to the real backend once it ships:** set
`PERFORMANCE_API_AVAILABLE=true` in `mobile/env/{dev,staging,prod}.json`
(per environment, as each is ready) — see
`AppConfig.isPerformanceApiAvailable` in
`lib/core/config/app_config.dart`. No other mobile code needs to change. If
the actual response shape ends up differing from this document, only
`performance_remote_data_source.dart` and the `data/models/*.dart` files
need updating — the domain layer, state management, and every screen are
unaffected.
