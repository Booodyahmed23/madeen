# Study Session / Question Bank API — required backend contract (not yet implemented)

**Status as of Phase 4 (mobile): these endpoints do not exist on the
backend.** Verified by inspection — `backend/src/modules/` currently
contains only `identity` and `notification`; there is no Question Bank or
Study Session module. This document is the mobile app's proposed contract,
written so whoever implements the backend module can do so without reading
Flutter code, and so both sides agree on shapes ahead of time. It mirrors
the style of `docs/API_AUTH.md` and `mobile/CURRICULUM_API_REQUIREMENTS.md`.

Until this exists, the mobile app runs entirely on local sample questions —
see "Current mobile-side status" at the bottom. **Do not treat this
document as an existing API** — no backend code has been written to match
it, and the exact endpoint paths below are a proposal, not a confirmed
contract.

## Why these shapes, and the security model they encode

This is the single most security-sensitive contract in the mobile app.
**The Flutter client must never be trusted as the authority for:**

- which choice is correct
- a question's final score / correctness
- entitlement to a topic's question set (subscription/paywall — out of
  scope this phase, but any future gate belongs here, not client-side)
- question availability

To enforce that structurally rather than just by convention, the *shape* of
each response is deliberately different depending on what point in the flow
it's returned from:

| Endpoint | May contain correct-answer info? |
|---|---|
| Start session (question list) | **No** — never |
| Submit one answer (immediate feedback) | Yes, for *that one question only* |
| Submit whole session | No (aggregate score only, not per-choice) |
| Get review | Yes, for every question (session is already over) |

The mobile domain layer mirrors this: `Question` (what's shown while
answering) has no correct-answer field at all — it is a different Dart type
from `QuestionFeedback` (immediate-mode, per-question) and
`QuestionReviewItem` (post-submission, full review). A coding mistake
cannot leak a correct answer early because the type simply doesn't carry
one at that stage. See `lib/features/study_session/domain/entities/`.

## Endpoints

All under the existing `/api/v1` prefix, alongside `/auth/*`, `/users/*`,
and the proposed `/programs`, `/parts`, `/units`, `/sub-units`, `/topics`
from `CURRICULUM_API_REQUIREMENTS.md`.

**Auth:** every endpoint below requires the same authenticated-user access
as Curriculum browsing (bearer access token, per `docs/API_AUTH.md`). A
`401` should be handled exactly like the rest of the app (silent refresh,
then redirect to login on failure — already wired globally via
`AuthInterceptor`, no study-session-specific handling needed).

### `POST /api/v1/study-sessions`

Starts a new session for one topic.

**Request:**

```json
{
  "topicId": "topic-flexible-budget",
  "questionCount": 20,
  "order": "random",
  "feedbackMode": "immediate"
}
```

| Field | Type | Notes |
|---|---|---|
| `topicId` | `string` | required |
| `questionCount` | `number` | one of `10, 20, 30, 40, 50` — the client never sends a custom amount; reject anything else with `400` |
| `order` | `"original" \| "random"` | if `"random"`, the **server** shuffles and returns the final order — the client never re-shuffles what it receives |
| `feedbackMode` | `"immediate" \| "atEnd"` | informational for the server's own bookkeeping; the client also enforces it locally, but the server should not rely on client enforcement for anything security-sensitive (there isn't anything security-sensitive gated by this field, since correct answers are withheld from the question list regardless of mode) |

**Response `201`:**

```json
{
  "sessionId": "sess-abc123",
  "questions": [
    {
      "id": "q-001",
      "text": "Under a flexible budget, which of the following...",
      "type": "MULTIPLE_CHOICE_SINGLE",
      "difficulty": "Medium",
      "choices": [
        { "id": "q-001-a", "text": "...", "order": 0 },
        { "id": "q-001-b", "text": "...", "order": 1 }
      ]
    }
  ]
}
```

- **`sessionId` is authoritative and required on every subsequent call.**
- Every question in `questions` **must not** include a correct-choice
  indicator, an explanation, or any other field hinting at correctness.
  Only `id`, `text`, `type`, `difficulty` (optional), and `choices`
  (`id`/`text`/`order`) belong here.
- `type` is currently always `"MULTIPLE_CHOICE_SINGLE"` — the client already
  has an extension point (`QuestionType` enum) for future types
  (multiple-response, calculation, case-based, image-based) but none of
  those are implemented this phase; do not add other type values yet.
- **Insufficient questions:** if fewer than `questionCount` questions exist
  for the topic, return as many as are available (not a `400`/`404`) — the
  client's UI already reads `questions.length`, not the requested count.
  An empty `questions: []` is a valid, if unusual, response; the client
  shows an empty-state message rather than crashing.

### `POST /api/v1/study-sessions/{sessionId}/answers`

Immediate-feedback mode only — records one answer and returns whether it
was correct. Never called in "feedback at end" mode.

**Request:**

```json
{ "questionId": "q-001", "selectedChoiceId": "q-001-b" }
```

`selectedChoiceId` may be `null` (student explicitly skips, then submits
anyway) — treat as unanswered/incorrect for this call, not as a `400`.

**Response `200`:**

```json
{
  "questionId": "q-001",
  "isCorrect": false,
  "correctChoiceId": "q-001-a",
  "explanation": "Flexible budgets adjust for..."
}
```

`isCorrect` and `correctChoiceId` here are the **only** place in the whole
flow a correct-choice id may appear before the session ends, and only for
the one question just answered.

### `POST /api/v1/study-sessions/{sessionId}/submit`

Finalizes the session. Called exactly once per session, in **both**
feedback modes (in immediate mode, this is still required even though every
individual answer was already recorded via the endpoint above — it's what
produces the authoritative aggregate score). The client sends this
idempotently-safely: a retry after a network failure re-sends the same
payload rather than assuming partial success.

**Request:**

```json
{
  "answers": { "q-001": "q-001-b", "q-002": null },
  "totalTimeSeconds": 742
}
```

`answers` is the complete question-id → selected-choice-id map, including
`null` for every question left unanswered. `totalTimeSeconds` is the
client-measured count-up timer — **advisory only**; if the server tracks
its own timing (e.g. from the `answers` submission timestamp), the server's
value is authoritative for anything that matters, since the client's timer
must never be trusted as authoritative either.

**Response `200`:**

```json
{
  "sessionId": "sess-abc123",
  "totalQuestions": 20,
  "answered": 18,
  "unanswered": 2,
  "correct": 14,
  "incorrect": 4,
  "scorePercent": 70.0,
  "totalTimeSeconds": 742,
  "averageTimePerQuestionSeconds": 37.1
}
```

Every field here is authoritative — the mobile Results screen renders these
numbers directly and does **not** recompute them from what it observed
locally during the session (see `lib/features/study_session/domain/entities/session_result.dart`).
Calling submit twice for the same session should be safe (return the same
already-computed result, or recompute deterministically) rather than
erroring — the client may retry this call after a failure without knowing
whether the first attempt actually landed.

### `GET /api/v1/study-sessions/{sessionId}/review`

Full per-question review. Only meaningful after `submit`; calling it before
should `409` or return `[]` (the client only ever calls it immediately
after a successful submit, so this is a defensive-only case).

**Response `200`:**

```json
[
  {
    "questionId": "q-001",
    "questionText": "Under a flexible budget, which of the following...",
    "choices": [
      { "id": "q-001-a", "text": "...", "order": 0 },
      { "id": "q-001-b", "text": "...", "order": 1 }
    ],
    "correctChoiceId": "q-001-a",
    "selectedChoiceId": "q-001-b",
    "isCorrect": false,
    "explanation": "Flexible budgets adjust for..."
  }
]
```

`selectedChoiceId` is `null` for a question the student left unanswered.
This is the only endpoint that returns every question's correct answer at
once — safe only because the session is already finalized by the time it's
ever called.

## Common behavior expected of every endpoint above

- **Errors:** the standard envelope from `docs/API_AUTH.md`
  (`{statusCode, message, error, path, timestamp, requestId}`). `401`/`403`
  per the normal auth rules, `404` for an unknown `sessionId`, `500` on
  server error. No study-session-specific error shape is needed.
- **Ordering:** the client never re-sorts or re-shuffles `choices` or
  `questions` — whatever order the server returns is what's shown and what
  is sent back in `answers`.
- **This is not the Exam Simulation contract.** Exam Simulation (timed,
  countdown, proctoring, analytics) is an explicitly separate, later
  feature — nothing here should be reused or overloaded for it.

## Current mobile-side status

The mobile app already has the full client-side abstraction ready for this
contract:

- `lib/features/study_session/domain/` — `Question`, `AnswerChoice`,
  `QuestionFeedback`, `SessionResult`, `QuestionReviewItem`,
  `StudySessionBundle`, `SessionConfig` entities and the
  `StudySessionRepository` interface.
- `lib/features/study_session/data/datasources/study_session_remote_data_source.dart`
  — implements the calls above exactly as documented. **Not yet exercised
  against a real server** — there is nothing to integration-test against.
- `lib/features/study_session/data/datasources/study_session_mock_data_source.dart`
  — generates a plausible sample question set for any topic, with an
  internally-consistent deterministic correct answer per question (so
  immediate feedback, the final score, and the review screen always agree
  with each other) — used instead of the real API until it exists.

**Switching to the real backend once it ships:** set
`STUDY_SESSION_API_AVAILABLE=true` in `mobile/env/{dev,staging,prod}.json`
(per environment, as each is ready) — see
`AppConfig.isStudySessionApiAvailable` in `lib/core/config/app_config.dart`.
No other mobile code needs to change. If the actual response shape ends up
differing from this document, only `study_session_remote_data_source.dart`
and the `data/models/*.dart` files need updating — the domain layer, state
management, and every screen are unaffected.
