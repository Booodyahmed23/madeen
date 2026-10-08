# Mobile ↔ backend API contract

Status: agreed baseline · Date: 2026-10-08 · Backend: `CMA_PLATFORM/backend` (NestJS)

## Ground rule

**The backend does not change. The mobile app adapts.** Every endpoint in
Part A already exists and is frozen: the mobile app renames fields, derives
values and changes flows to match it. Part B lists the endpoints the
backend still has to build (full contract in
`CMA_PLATFORM/docs/MOBILE_MISSING_APIS.md`) and what the mobile app changes to
consume them.

This replaces the old `*_API_REQUIREMENTS.md` files at the repo root, which
were written before the backend existed. Delete them once the integration
lands, except the AI and course ones, which stay as V2 input.

**Scope: V1.** AI analysis, AI tutor and courses/video lessons are V2 and are
not part of this contract (see "Out of scope — V2").

---

## 0. Global changes (do these first)

| # | Area | Change | File(s) |
|---|---|---|---|
| G1 | Base URL | Dev: `http://localhost:3001/api/v1` (iOS simulator) / `http://10.0.2.2:3001/api/v1` (Android emulator). Preview/staging: `https://kasbana.net/api/v1` (the website proxies `/api` to the backend). | `env/*.json`, `app_config.dart` default |
| G2 | Error envelope | Backend: `{ statusCode, error, message: string \| string[], code?, details?, path, timestamp }`. **No `requestId`.** Add `code` and `details` to `ApiException` and drop `requestId`. Map `code` to localized messages in `failure_messages.dart`. | `api_exception.dart`, `api_client.dart`, `core/error/*` |
| G3 | Pagination | Lists return `{ data: T[], meta: { page, limit, total, totalPages } }`. Query `page` (≥1) and `limit` (1–100, default 20). There is no `offset`. Add a shared `Paginated<T>` model; "has more" means `page < totalPages`. | new `core/network/paginated.dart` |
| G4 | Unknown fields | The backend rejects **any** unknown body or query field with `400`. Send only the fields listed here. | all remote data sources |
| G5 | Auth retry rule | `AuthInterceptor` currently skips refresh-and-retry for every `/auth/` path. Skip it **only** for `/auth/login`, `/auth/register`, `/auth/refresh`, `/auth/logout` and `/auth/password-reset/*`. `/auth/me` and `/auth/change-password` must refresh and retry like any other call. | `auth_interceptor.dart` |
| G6 | Enums | Backend enums are UPPER_SNAKE: `EASY/MEDIUM/HARD`, `IMMEDIATE/DEFERRED`, `IN_PROGRESS/PAUSED/COMPLETED`, `SUBMITTED/EXPIRED`, `STUDY/EXAM`, `USER/ADMIN`. Map them in the data layer only. | models |
| G7 | Language | Curriculum, questions and choices are **single-language** (as authored). There is no `locale` parameter on existing endpoints. Show text as-is; UI chrome stays localized. | — |
| G8 | Entitlement | `403` with message `An active subscription is required` (or `No active subscription covers one or more selected topics`) comes back when **starting** a study session or exam. Map it to a "no access" failure that opens the Plans screen. | `failure_mapper.dart` |
| G9 | Rate limits | `429` limits: login 10/min, register 5/min, password reset request 3/min, reset confirm 5/min, change password 5/min, coupon validate 10/min, coupon redeem 5/min, study and exam creation 20 per 10 min. | — |

Error `code` values the app should translate: `WRONG_CURRENT_PASSWORD`,
`NOT_FOUND`, `COUPON_INVALID`, `COUPON_NOT_ACTIVE`, `COUPON_WRONG_PLAN`,
`COUPON_EXHAUSTED`, `COUPON_ALREADY_USED`, `COUPON_NOT_FREE`,
`PLAN_UNAVAILABLE`.

---

# Part A — existing endpoints (frozen)

## A1. Auth

The refresh token is **not** in the response body. The backend sets it as a
cookie: `Set-Cookie: refresh_token=<raw>; Path=/api/v1/auth; HttpOnly; …`.
A mobile client is not a browser, so it handles the cookie by hand:

1. On login, register and refresh, read the `set-cookie` response header and
   extract `refresh_token=<value>`.
2. Save the value in `SecureStorage` (as today).
3. For refresh and logout, send the header `Cookie: refresh_token=<value>`.
4. Refresh **rotates** the token. Always save the new cookie value. Reusing an
   old token revokes every session for that user (the existing single-flight
   refresh in `AuthInterceptor` already guards against this).

`ApiClient` needs a variant that exposes the response headers (for example
`postWithHeaders`) for these three calls.

| Mobile today | Backend (use this) | Request | Response |
|---|---|---|---|
| `POST /auth/register` | same | `{ email (≤254), password (8–200), firstName (1–100), lastName (1–100) }` | `201` `{ accessToken }` + cookie. `409` "Email already in use" |
| `POST /auth/login` | same | `{ email, password }` | `200` `{ accessToken }` + cookie. `401` on bad credentials |
| `POST /auth/refresh` body `{refreshToken}` | `POST /auth/refresh`, **no body**, header `Cookie: refresh_token=…` | — | `200` `{ accessToken }` + **new** cookie. `400` "Missing refresh token", `401` "Invalid refresh token" |
| `POST /auth/logout` body `{refreshToken}` | `POST /auth/logout`, no body, `Cookie` header | — | `204` |
| `POST /auth/forgot-password` | `POST /auth/password-reset/request` | `{ email }` | `200` `{ message }` (always, even for unknown emails) |
| `POST /auth/reset-password` | `POST /auth/password-reset/confirm` | `{ token, newPassword (8–200) }` | `200` `{ message }`. **All sessions are revoked**, so send the user to Login |
| `GET /users/me` | `GET /auth/me` | — | `200` `{ id, email, firstName, lastName, role }` |
| `PATCH /users/me` | same | `{ firstName?, lastName? }` | `200` `{ id, email, firstName, lastName, role, isActive, createdAt, updatedAt }` |
| *(none)* | `POST /auth/change-password` | `{ currentPassword, newPassword (8–200) }` | `200` `{ accessToken }` + new cookie (other devices are signed out). `400` code `WRONG_CURRENT_PASSWORD` |

**Mobile changes**
- `AuthResponseModel`: only `accessToken` comes from the body, and
  `refreshToken` comes from the cookie. Register, login and refresh return
  **no user**, so call `GET /auth/me` right after (also in `restoreSession`).
- `UserProfileModel` / `AuthUser`: `roles: List<String>` becomes
  `role: String` (`USER` | `ADMIN`); `isAdmin => role == 'ADMIN'`.
- Add a Change Password screen and remove it from the "backend-blocked" table
  in `features/auth/README.md`.
- Validators: password 8–200, names 1–100, email ≤254.
- Password reset email: the backend mailer is currently a placeholder (it logs
  only), so the reset flow cannot be completed end to end until an email
  provider is configured.

## A2. Curriculum

Students see published nodes only. There is **no entitlement check on
browsing**: every signed-in user can browse every published program.

**Recommended:** one call per program instead of five levels.

| Mobile today | Backend (use this) |
|---|---|
| `GET /programs` | `GET /curriculum/programs?page=1&limit=100` → `{ data, meta }` |
| `GET /programs/{id}/parts` … `GET /sub-units/{id}/topics` | `GET /curriculum/programs/:id/tree` (preferred) or the level endpoints below |
| — | `GET /curriculum/programs/:programId/parts`, `/curriculum/parts/:partId/units`, `/curriculum/units/:unitId/sub-units`, `/curriculum/sub-units/:subUnitId/topics` (each paginated) |
| — | `GET /curriculum/{programs\|parts\|units\|sub-units\|topics}/:id` — one node; `404` if unpublished |

Node fields: `{ id, name, description|null, order, isPublished, createdAt, updatedAt }`
plus the parent key (`programId` / `partId` / `unitId` / `subUnitId`).

Tree response:

```json
{ "id": "…", "name": "CMA", "description": null, "order": 0, "isPublished": true, "createdAt": "…", "updatedAt": "…",
  "parts": [{ "id": "…", "programId": "…", "name": "Part 1", "order": 0, "…": "…",
    "units": [{ "…": "…", "subUnits": [{ "…": "…",
      "topics": [{ "id": "…", "subUnitId": "…", "name": "Budgeting", "order": 0, "…": "…",
                   "questionCounts": { "DRAFT": 0, "PUBLISHED": 42, "ARCHIVED": 0 } }] }] }] }] }
```

**Mobile changes**
- `ProgramModel`: **remove `code`** (today a required cast, so it crashes)
  and remove `imageUrl`. `isActive` becomes `isPublished`.
- All models: ids are UUIDs, and `name` / `description` are single-language.
- Parse the `{ data, meta }` lists (G3). Prefer the tree endpoint and build the
  Part → Unit → Sub-unit → Topic screens from it in memory.
- Use `questionCounts.PUBLISHED` to disable topics that have no questions.
- Default program: the first item from `GET /entitlements/me` (see A6).

## A3. Study sessions

| Mobile today | Backend (use this) |
|---|---|
| `POST /study-sessions` | `POST /study/sessions` |
| `POST /study-sessions/{id}/answers` | `PATCH /study/sessions/:id/questions/:questionId/answer` |
| `POST /study-sessions/{id}/submit` | `POST /study/sessions/:id/complete` (no body) |
| `GET /study-sessions/{id}/review` | `GET /study/sessions/:id` (after complete) |
| — | `GET /study/sessions?page&limit` (list) |
| — | `GET /study/sessions/:id` (fetch or resume) |
| — | `PATCH /study/sessions/:id/pause`, `PATCH /study/sessions/:id/resume` |
| — | `PATCH /study/sessions/:id/questions/:questionId/flag` body `{ flagged: boolean }` |

**Create** request:
- `topicIds?: uuid[]` (omit for all entitled topics)
- `questionCount: int 1–100` (required)
- `feedbackMode?: IMMEDIATE | DEFERRED` (default IMMEDIATE)
- `difficulty?: EASY | MEDIUM | HARD`

Create returns `201` with the Session object.

**Answer** request: `{ choiceId: uuid (required), timeSpentSeconds?: int 0–3600 }`.
`timeSpentSeconds` is **added** to the stored total, so send only the time
spent since the last call. Answer returns the Session object.

Session object (returned by every study endpoint):

```json
{ "id": "…", "userId": "…", "status": "IN_PROGRESS", "feedbackMode": "IMMEDIATE",
  "topicIds": ["…"], "difficulty": null, "requestedCount": 20,
  "createdAt": "…", "updatedAt": "…", "completedAt": null,
  "progress": { "total": 20, "answered": 3, "flagged": 1, "correct": 2 },
  "questions": [{
    "id": "<session-question id>", "questionId": "<bank question id — use in URLs>", "order": 0,
    "isFlagged": false, "answeredAt": null, "timeSpentSeconds": 0,
    "selectedChoiceId": null, "isCorrect": null,
    "question": { "id": "…", "text": "…", "topic": { "id": "…", "name": "…", "description": null },
                  "code": 101, "losCode": null, "difficulty": "MEDIUM", "explanation": null },
    "choices": [{ "id": "…", "text": "…" }]
  }]
}
```

Reveal rule: a question is revealed when it has been answered **and**
(`feedbackMode = IMMEDIATE` **or** `status = COMPLETED`). Revealed questions
carry `isCorrect`, `question.explanation` and `choices[].isCorrect`.

**Errors**
- `400` "No published questions match the selection criteria" (zero questions).
- `403` no entitlement (G8).
- `400` when answering while `PAUSED` or `COMPLETED`.
- `400` when completing a session that is already `COMPLETED`.
- `404` for an unknown session or a question that is not in it.

**Mobile changes**

| Mobile field / behaviour | Change to |
|---|---|
| `topicId` | `topicIds: [topicId]` |
| `order: original\|random` | **remove** (the server always shuffles); drop the option from Setup |
| `feedbackMode: immediate\|atEnd` | `IMMEDIATE` \| `DEFERRED` |
| question count picker 10–50 | any value 1–100 is valid; keep the presets |
| response `sessionId` | `id` |
| `questions[].text` | `questions[].question.text` |
| `questions[].type` | absent; always single-answer MCQ |
| `choices[].order` | absent; use the array index |
| difficulty `"Medium"` | `MEDIUM` |
| ids used in URLs | `questions[].questionId` (not `questions[].id`) |
| bulk `answers` map at submit | `PATCH …/answer` **every time** the student picks a choice, in both modes |
| skipped answer (`null`) | do not call the API; an unanswered question stays `answeredAt: null` |
| `QuestionFeedback { isCorrect, correctChoiceId, explanation }` | from the returned session's question: `isCorrect`, `choices.firstWhere(c.isCorrect).id`, `question.explanation` (IMMEDIATE mode only) |
| re-answer after feedback | the backend allows it. **Lock it on the client**: locked if `status != IN_PROGRESS` or (`IMMEDIATE` and `answeredAt != null`) |
| `POST …/submit` | `POST …/complete`; on `400` "already completed", `GET` the session and continue |
| `SessionResult` | derived (see table below) |
| review list | built from the completed session. **Skipped questions have no correct answer revealed**, so `correctChoiceId` is nullable in review |
| `0 questions → []` | `400`: show the empty-state message |

Derived `SessionResult`:

| Field | Formula |
|---|---|
| `totalQuestions` | `progress.total` |
| `answered` | `progress.answered` |
| `correct` | `progress.correct` |
| `incorrect` | `answered - correct` |
| `unanswered` | `total - answered` |
| `scorePercent` | `correct / total * 100` |
| `totalTimeSeconds` | `Σ questions[].timeSpentSeconds` |
| `averageTimePerQuestionSeconds` | `totalTimeSeconds / answered` |

**New capabilities to use:** resume an unfinished session (list it from
`GET /study/sessions` where `status != COMPLETED`), pause/resume, and
server-side flags.

## A4. Exam simulation

| Mobile today | Backend (use this) |
|---|---|
| `POST /exam-attempts` | `POST /exams/attempts` |
| `GET /exam-attempts/{id}` | `GET /exams/attempts/:id` |
| `POST /exam-attempts/{id}/submit` (body) | `POST /exams/attempts/:id/submit` (**no body**, idempotent) |
| `GET /exam-attempts/{id}/review` | `GET /exams/attempts/:id` after submit |
| — | `PATCH /exams/attempts/:id/questions/:questionId/answer` body `{ choiceId, timeSpentSeconds? }` |
| — | `PATCH /exams/attempts/:id/questions/:questionId/flag` body `{ flagged }` |
| — | `GET /exams/attempts?page&limit` |

**Create** request:
- `topicIds?: uuid[]`
- `questionCount: int 1–100`
- `durationMinutes: int 5–300`
- `difficulty?`

Create returns `201` with the Attempt object.

Attempt object: the same question/choice shape as a study session, plus
`status: IN_PROGRESS | SUBMITTED | EXPIRED`, `durationMinutes`, `startedAt`,
`expiresAt`, `submittedAt`, `remainingSeconds`,
`progress: { total, answered, flagged }` and
`score: { correct, incorrect, unanswered } | null`. Once the attempt is not
`IN_PROGRESS`, **every** question is revealed, including unanswered ones.

The server owns the clock: an attempt read or written after `expiresAt`
becomes `EXPIRED` automatically.

**Mobile changes**

| Mobile field / behaviour | Change to |
|---|---|
| `programId, partId, unitId, subUnitId` | resolve the selected node to its topic ids using the curriculum tree, then send `topicIds` |
| `questionOrder` | **remove** (always shuffled) |
| `durationSeconds` | `durationMinutes = clamp(ceil(seconds / 60), 5, 300)` |
| response `attemptId` | `id` |
| countdown | start from `remainingSeconds`; re-sync from `expiresAt` after the app returns from background |
| answers held locally until submit | `PATCH …/answer` on every selection; `PATCH …/flag` on every flag |
| "clear answer" | not supported by the backend; remove the action |
| topic shown during the exam | the payload includes `question.topic`; **do not display it** while `IN_PROGRESS` |
| `POST submit {answers…}` | `POST submit` with no body; it returns the final attempt |
| auto-submit at 0 | call `submit` anyway; the response is `EXPIRED` |

Derived `ExamResult`:

| Field | Formula |
|---|---|
| `totalQuestions` | `progress.total` |
| `correct`, `incorrect`, `unanswered` | `score.*` |
| `answered` | `total - unanswered` |
| `scorePercent` | `correct / total * 100` |
| `durationTakenSeconds` | `submittedAt - startedAt` |
| `completionStatus` | `SUBMITTED → completed`, `EXPIRED → timedOut` |

Review item: `correctChoiceId = choices.firstWhere(c.isCorrect).id`,
`explanation = question.explanation`, `topicId/topicName = question.topic`,
`wasFlagged = isFlagged`.

Topic breakdown: group `questions[]` by `question.topic.id` on the client.

## A5. Performance & history

| Mobile today | Backend (use this) |
|---|---|
| `GET /performance/topics?attemptType` | `GET /results/performance/topics` (no filter; study and exam combined) |
| `GET /performance/attempts?attemptType&limit&offset` | `GET /results/history?page&limit` |
| `GET /performance/attempts/:id` | `GET /study/sessions/:id` or `GET /exams/attempts/:id`, chosen by `type` |
| `GET /performance/overview` | **derived on the client** (see below) |
| — | `GET /results/performance/parts` |
| — | `GET /results/performance/trend?days=7&tzOffsetMinutes=<DateTime.now().timeZoneOffset.inMinutes>` (east of UTC is positive, e.g. `180` for UTC+3) |

`PerformanceEntry` (topics and parts) is
`{ id, name, correct, total, accuracy, avgTimeSeconds|null }`, where `accuracy`
is a percentage with one decimal (correct ÷ answered). Only revealed answers
are counted.

Trend entries are `{ date: "YYYY-MM-DD", correct, total, accuracy|null }`
(`days` 1–90).

History item:

```json
{ "type": "STUDY", "id": "…", "status": "COMPLETED", "createdAt": "…", "finalizedAt": "…",
  "requestedCount": 20, "topicIds": ["…"], "difficulty": null,
  "answeredCount": 18, "correctCount": 14, "totalTimeSeconds": 640 }
```

`correctCount` is `null` until the attempt is revealed.

**Mobile changes**

| Mobile | Change to |
|---|---|
| `TopicPerformance { topicId, topicName, questionsAttempted, answered, correct, wrong, averageTimePerQuestionSeconds }` | `topicId = id`, `topicName = name`, `answered = total`, `correct`, `wrong = total - correct`, `averageTimePerQuestionSeconds = avgTimeSeconds`. `questionsAttempted` is not available, so use `total` |
| `AttemptType` wire `STUDY_SESSION` / `EXAM_SIMULATION` | `STUDY` / `EXAM` (the current `fromWire` **throws** on these) |
| `attemptId` | `id` |
| `completedAt` | `finalizedAt` (`null` means in progress) |
| `answered` | `answeredCount` |
| `correct` | `correctCount ?? 0` |
| `durationSeconds` | `totalTimeSeconds` |
| `totalQuestions` | `requestedCount` (the requested number, not the served number; the details screen uses the real count) |
| `contentLabel` | resolve `topicIds` to names via the curriculum tree (for example "Budgeting +2") |
| `scorePercent` | `correctCount / requestedCount * 100` in the list; exact value on details |
| in-progress attempts in history | the backend includes them: show them as "Resume" rows, or filter out `finalizedAt == null` |
| `attemptType` filter | filter on the client (`type`). Note: with a filter, page counts refer to the unfiltered list |
| `limit/offset`, `{items, hasMore}` | `page/limit`, `{ data, meta }` |
| attempt details | fetch the session or attempt and reuse the A3/A4 derivations and topic grouping |
| overview | `totalAttempts = meta.total`. Accuracy is Σcorrect / Σtotal over `performance/topics`. Best and weak topics come from the same list |

The local attempts store (`performance_local_data_source.dart`,
`local_attempts_provider.dart`) becomes unnecessary once history comes from
the server. Keep it only as an offline cache.

## A6. Plans, access and coupons (new screens; the backend already supports them)

| Endpoint | Response |
|---|---|
| `GET /entitlements/me` | `[{ id, userId, programId, subscriptionId, startsAt, expiresAt, revokedAt, createdAt, program: { id, name } }]`, active only, soonest expiry first |
| `GET /subscriptions/me` | `[{ id, userId, planId, status: ACTIVE\|CANCELLED, source: PAYMENT\|ADMIN\|COUPON, startsAt, endsAt, cancelledAt, createdAt, updatedAt, plan: { id, name, programId }, entitlement: { startsAt, expiresAt, revokedAt } \| null }]` |
| `GET /plans` (public) | `[{ id, programId, name, description, priceCents, currency, durationDays, isActive, createdAt, updatedAt, program: { id, name } }]`, cheapest first |
| `POST /coupons/validate` `{ code (3–40), planId }` | `200` `{ code, planId, currency, priceCents, amountOffCents, finalPriceCents }` |
| `POST /coupons/redeem` `{ code, planId }` | `201` `{ redemption, subscription }`. Works only when the final price is 0; otherwise `400 COUPON_NOT_FREE` |

Prices are in minor units (cents). Online payment is **not available yet**
(the backend is waiting on Paymob keys). Show paid plans as "contact us" or
coupon-only; never fake a checkout.

Mobile work: build `features/subscription` (Plans & access screen, coupon
entry) and gate the Study and Exam setup CTAs on `GET /entitlements/me`
being non-empty.

## A7. Health

`GET /health` (public) returns `200` with `database: "ok"`, or `503`. It is
optional, for a "server unreachable" banner.

---

# Part B — endpoints still to be built by the backend

Full specification: `CMA_PLATFORM/docs/MOBILE_MISSING_APIS.md`. Each module
stays on its mock data source until its flag is turned on.

| Module | Flag | Mobile changes when it ships |
|---|---|---|
| Notifications | `NOTIFICATIONS_API_AVAILABLE` | List is paginated `{ data, meta }` (was a plain array); `PATCH /notifications/:id/read` has **no body**; `read-all` returns `{ updated }`; `DELETE` returns `204`; preferences `PATCH` may send only the changed keys; the item gains `readAt`; `action` may be `null` and uses the new type names below; the `AI_RECOMMENDATION` type and the `aiRecommendations` preference are removed (V2), so preferences have 7 keys and the AI toggle is hidden |
| Study reminders | (same flag) | Same fields as today plus `updatedAt`; handle `400 REMINDER_LIMIT_REACHED` (max 20) and `INVALID_CUSTOM_DAYS` |
| Push devices | new `PUSH_API_AVAILABLE` | `POST /devices { token, platform: IOS\|ANDROID, locale }` after login; `DELETE /devices/:token` on logout |

Notification `action.type` renames:

| Old wire value | New wire value |
|---|---|
| `openStudySessionSetup` | `OPEN_STUDY_SETUP` |
| `openExamSetup` | `OPEN_EXAM_SETUP` |
| `openPerformanceOverview` | `OPEN_PERFORMANCE` |
| `openTopicPerformance` | `OPEN_TOPIC_PERFORMANCE` |
| `openAttemptDetails` | `OPEN_ATTEMPT` (+ `attemptType: STUDY\|EXAM`) |
| `openAiAnalysisOverview`, `openAiAnalysisTopic`, `openAiAnalysisAttempt` | removed (V2) |
| `none` | `action: null` |
| — | `OPEN_PLANS` (new) |

## Out of scope — V2

**AI analysis, AI tutor and courses/video lessons are V2.** The backend will
not build them in V1, and the mobile app does not integrate them now:

- Hide their entry points in V1 builds: the Home AI teaser card, the AI
  analysis screens, the AI tutor screen and the Courses screens. Keep the
  code and its mock data sources for V2. Do not ship mock AI or course
  content to real users.
- Keep `AI_ANALYSIS_API_AVAILABLE`, `AI_TUTOR_API_AVAILABLE` and
  `COURSE_API_AVAILABLE` off.
- The old `AI_ANALYSIS_*`, `AI_TUTOR_*` and `COURSE_API_REQUIREMENTS.md`
  files are kept only as V2 input; they are not a contract.

---

## Suggested integration order

1. G1–G9 (global changes).
2. A1 auth.
3. A2 curriculum.
4. A6 access check (needed so Study and Exam can show "no access").
5. A3 study sessions.
6. A4 exams.
7. A5 performance (replaces local attempt recording).
8. Part B modules (notifications, reminders, push), as each backend module ships.

For each step: switch the module's `*_API_AVAILABLE` flag on in `env/dev.json`,
update `test/features/<module>` fixtures to the shapes above, and run against
the seeded backend (`student@madeen.dev` / `Password123!`).
