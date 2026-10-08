# Exam Simulation API — required backend contract (not yet implemented)

**Status as of Phase 5 (mobile): these endpoints do not exist on the
backend.** Verified by inspection — `backend/src/modules/` currently
contains only `identity` and `notification`; there is no Exam Simulation
module. This document is the mobile app's proposed contract, written so
whoever implements the backend module can do so without reading Flutter
code, and so both sides agree on shapes ahead of time. It mirrors the style
of `docs/API_AUTH.md`, `mobile/CURRICULUM_API_REQUIREMENTS.md`, and
`mobile/STUDY_SESSION_API_REQUIREMENTS.md`.

Until this exists, the mobile app runs entirely on a local mock exam — see
"Current mobile-side status" at the bottom. **Do not treat this document as
an existing API** — no backend code has been written to match it, and the
exact endpoint paths below are a proposal, not a confirmed contract.

**This is a separate contract from Study Session's.** Exam Simulation and
Study Session are architecturally distinct experiences on the mobile side
(see `lib/features/exam_simulation/README.md`) and nothing here should be
merged with or reused from `STUDY_SESSION_API_REQUIREMENTS.md`, even where
shapes look similar.

## OPEN / BACKEND DECISION: exam configuration

**The mobile app does not know, and must not invent, the real CMA/FMAA
exam configuration** — official per-part question counts, the officially
allowed duration, testlet structure (e.g. multiple-choice + essay
sections), or any other certification business rule. Those are business/
certification decisions outside this app's scope.

Until the backend defines them, the Setup screen offers mobile-side
placeholder presets only:

- `kExamQuestionCountOptions = [25, 50, 75, 100]`
  (`lib/features/exam_simulation/domain/entities/exam_config.dart`)
- `kExamDurationOptions = [30m, 1h, 2h, 3h]` (same file)

These are **not** real exam requirements. When the backend has an
authoritative exam-configuration concept (e.g. "CMA Part 1 = 100 questions,
4 hours"), replace these lists and/or drive them from a new
`GET /exam-configurations` style endpoint — no other mobile code should
need to change, since the Setup screen already treats these as a plain
list of options.

## Why these shapes, and the security model they encode

Same security posture as Study Session, restated for exam-specific
concerns. **The Flutter client must never be trusted as the authority
for:**

- which choice is correct
- the final score
- the exam's allowed duration (the client's requested duration in
  `startExam` is just a request — see [`POST /exam-attempts`](#post-apiv1exam-attempts))
- whether an attempt is still valid / has expired
- exam completion status
- entitlement to take an exam (subscription/paywall — out of scope this
  phase, but any future gate belongs here, not client-side)

Additionally, **exam questions must never carry topic/curriculum context**
(program/part/unit/sub-unit/topic name or id) in their payload — this is
both a UX rule ("no topic display" during the exam) and, more importantly,
an architectural one: the mobile `ExamQuestion` entity has no field for it,
so a coding mistake cannot leak it even if a future response accidentally
included it.

| Endpoint | May contain correct-answer info? | May contain topic/curriculum info? |
|---|---|---|
| Start exam (question list) | **No** — never | **No** — never |
| Submit exam (aggregate score) | No (aggregate only, not per-choice) | No |
| Get review | Yes, for every question (attempt is already over) | Yes — optional `topicId`/`topicName` per question (attempt is already over), used for the results screen's per-topic breakdown and Performance topic analytics |

## Endpoints

All under the existing `/api/v1` prefix, alongside `/auth/*`, `/users/*`,
the proposed Curriculum endpoints, and the proposed Study Session
endpoints.

**Auth:** every endpoint below requires the same authenticated-user access
as the rest of the app (bearer access token, per `docs/API_AUTH.md`).

### `POST /api/v1/exam-attempts`

Starts a new exam attempt for one Program + Part.

**Request:**

```json
{
  "programId": "program-cma",
  "partId": "cma-part-1",
  "unitId": null,
  "subUnitId": null,
  "questionCount": 20,
  "questionOrder": "original",
  "durationSeconds": 1800
}
```

| Field | Type | Notes |
|---|---|---|
| `programId` / `partId` | `string` | required — the certification scope this attempt covers |
| `unitId` / `subUnitId` | `string \| null` | optional narrowing of the scope (Phase 15): `null` means the whole Part / whole Unit. `subUnitId` is only sent together with `unitId` |
| `questionOrder` | `"original" \| "random"` | requested ordering (Phase 15); the order of the returned `questions` array is authoritative |
| `questionCount` | `number` | one of the mobile-side presets today (see "OPEN / BACKEND DECISION" above) — the server is free to reject, clamp, or override this once it has a real configuration concept |
| `durationSeconds` | `number` | **the client's requested duration — advisory only.** The response's own `durationSeconds` is what the client actually counts down from; the server may return a different value (e.g. an entitlement-based or certification-mandated duration) |

**Response `201`:**

```json
{
  "attemptId": "attempt-abc123",
  "durationSeconds": 14400,
  "questions": [
    {
      "id": "q-001",
      "text": "Under a flexible budget, which of the following...",
      "type": "MULTIPLE_CHOICE_SINGLE",
      "choices": [
        { "id": "q-001-a", "text": "...", "order": 0 },
        { "id": "q-001-b", "text": "...", "order": 1 }
      ]
    }
  ]
}
```

- **`attemptId` and the response's `durationSeconds` are authoritative and
  required on every subsequent call / for seeding the countdown.**
- Every question **must not** include a correct-choice indicator, an
  explanation, or **any topic/curriculum field** — only `id`, `text`,
  `type`, and `choices` (`id`/`text`/`order`) belong here.
- `type` is currently always `"MULTIPLE_CHOICE_SINGLE"` — same extension
  point as Study Session's `QuestionType`, no other values implemented yet.
- **Insufficient questions:** return as many as are available, not a
  `400`/`404` — the client reads `questions.length`, not the requested
  count. An empty `questions: []` is a valid response; the client shows an
  empty-state message.

### `GET /api/v1/exam-attempts/{attemptId}`

Reloads an in-progress attempt. **Not wired into any mobile screen this
phase** — there is no local persistence of an in-progress attempt id to
reconnect to after the app process is killed (see "Known limitations"
below) — but documented and implemented client-side (mock + remote data
source, repository interface) since a future persistence layer will need
it, and because a resume flow is a reasonable near-term addition once one
exists.

**Response `200`:** identical shape to the `startExam` response.
**`404`** for an unknown or already-submitted attempt.

### `POST /api/v1/exam-attempts/{attemptId}/submit`

Finalizes the attempt. Called exactly once per attempt — either by the
student pressing Submit, or automatically by the client when its countdown
reaches zero (see "Auto-submission on timeout" below).

**Request:**

```json
{
  "answers": { "q-001": "q-001-b", "q-002": null },
  "flaggedQuestionIds": ["q-004", "q-017"],
  "timeTakenSeconds": 13920
}
```

| Field | Type | Notes |
|---|---|---|
| `answers` | `object` | complete question-id → selected-choice-id map, `null` for unanswered |
| `flaggedQuestionIds` | `string[]` | for the post-exam review only — **must never affect scoring** |
| `timeTakenSeconds` | `number` | client-measured countdown elapsed — **advisory only**, same reasoning as Study Session's `totalTimeSeconds`. If the server tracks its own timing (e.g. from a stored start timestamp), the server's value is authoritative |

**Response `200`:**

```json
{
  "attemptId": "attempt-abc123",
  "totalQuestions": 100,
  "answered": 94,
  "unanswered": 6,
  "correct": 71,
  "incorrect": 23,
  "scorePercent": 71.0,
  "durationTakenSeconds": 13920,
  "completionStatus": "completed"
}
```

`completionStatus` is an opaque, server-defined string (the mobile
`ExamResult` entity treats it as such) — the client currently recognizes
`"completed"` and `"timed_out"` for display purposes and falls back to
showing an unrecognized value verbatim, so the backend is free to add more
values without a client update being strictly required (though the display
label would be unlocalized for anything new until the client is updated).

Every field is authoritative — the Results screen renders these directly,
never recomputing from what it observed locally during the exam. Calling
submit twice for the same attempt should be safe (idempotent) — the client
may retry this call after a network failure without knowing whether the
first attempt actually landed.

### `GET /api/v1/exam-attempts/{attemptId}/review`

Full per-question review. Only meaningful after submit.

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
    "wasFlagged": true,
    "explanation": "Flexible budgets adjust for...",
    "topicId": "topic-flexible-budget",
    "topicName": "Flexible Budget"
  }
]
```

`topicId`/`topicName` (optional, Phase 15) classify the question for the
post-submission per-topic breakdown — revealed only here, never on the
start-exam question payload.

`wasFlagged` reflects the student's own flag from during the exam — shown
back to them for reference only, and (as above) must never have influenced
`isCorrect`/scoring.

## Auto-submission on timeout

When the mobile client's countdown reaches zero, it calls
`POST /exam-attempts/{attemptId}/submit` automatically with whatever
answers/flags exist at that moment (see `ExamNotifier._handleTimeout` in
`lib/features/exam_simulation/presentation/providers/exam_notifier.dart`).

**This client timer is a UX countdown, not the security boundary.** A
production backend must independently enforce the real deadline — e.g.
reject or truncate a submission that arrives suspiciously late relative to
the attempt's start timestamp plus its authoritative duration, and/or
proactively expire an attempt server-side rather than relying on the
client ever calling submit at all (a killed app, lost connectivity, or a
manipulated client could otherwise never send the timeout submission).
`completionStatus: "timed_out"` in the result response is intended for
exactly this case — the client sends whatever answers it has, but the
server decides whether to label the outcome as a normal completion or a
timeout based on its own authoritative timing, not by trusting a
client-sent flag.

## Known limitations of the current mobile-side timer

Documented in `ExamNotifier`'s doc comment too:

- **No process-kill resilience.** The countdown lives entirely in-memory
  (a `Timer.periodic` inside the Riverpod notifier). It correctly survives
  widget rebuilds and briefly backgrounding the app (the provider
  container isn't tied to any one screen's lifecycle), but a fully killed
  app process loses all attempt state — there is no local persistence this
  phase. `GET /exam-attempts/{attemptId}` exists in the client's
  abstraction specifically so a future "resume my in-progress attempt" flow
  can be built on top of it.
- **Not wall-clock-exact across backgrounding.** OS-level background
  execution limits can throttle a `Timer` while the app is backgrounded, so
  elapsed real time and the client's tick count can drift apart during a
  long backgrounding. A server-authoritative deadline (computed from a
  stored start timestamp, not from a client-reported elapsed time) is the
  only fully correct fix, and is a backend responsibility once this module
  exists.

## Common behavior expected of every endpoint above

- **Errors:** the standard envelope from `docs/API_AUTH.md`
  (`{statusCode, message, error, path, timestamp, requestId}`). `401`/`403`
  per the normal auth rules, `404` for an unknown `attemptId`, `500` on
  server error.
- **Ordering:** the client never re-sorts or re-shuffles `choices` or
  `questions` — whatever order the server returns is what's shown and what
  is sent back in `answers`.
- **This is not the Study Session contract.** Nothing here should be
  reused or overloaded for Study Session, and vice versa — see this
  document's opening note.

## Current mobile-side status

The mobile app already has the full client-side abstraction ready for this
contract:

- `lib/features/exam_simulation/domain/` — `ExamQuestion`,
  `ExamAnswerChoice`, `ExamConfig`, `ExamAttempt`, `ExamResult`,
  `ExamReviewItem` entities and the `ExamRepository` interface.
- `lib/features/exam_simulation/data/datasources/exam_remote_data_source.dart`
  — implements the calls above exactly as documented. **Not yet exercised
  against a real server** — there is nothing to integration-test against.
- `lib/features/exam_simulation/data/datasources/exam_mock_data_source.dart`
  — generates a plausible sample exam for any `ExamConfig`, with an
  internally-consistent deterministic correct answer per question (so the
  final score and the post-exam review always agree with each other), and
  deliberately no topic/curriculum text anywhere in the generated content
  — used instead of the real API until it exists. **This mock data is a
  UI-development aid only — it is not, and must never be mistaken for,
  real or production-ready exam content.**

**Switching to the real backend once it ships:** set
`EXAM_SIMULATION_API_AVAILABLE=true` in
`mobile/env/{dev,staging,prod}.json` (per environment, as each is ready) —
see `AppConfig.isExamSimulationApiAvailable` in
`lib/core/config/app_config.dart`. No other mobile code needs to change. If
the actual response shape ends up differing from this document, only
`exam_remote_data_source.dart` and the `data/models/*.dart` files need
updating — the domain layer, state management, and every screen are
unaffected.
