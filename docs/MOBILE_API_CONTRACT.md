# Mobile API contract

Status: agreed baseline · Updated: 2026-10-08 · API base: `/api/v1`

## Ground rule

**The API is fixed. Only the mobile app's code changes.** Everything in this
document describes the API exactly as it is; the website already runs on
it. Do not ask for, plan or make changes to the API: the app renames fields,
derives values and changes flows to match it. If something the app needs
seems to be missing, raise it with the API team instead of working around it.

The student website (`https://kasbana.net`) uses the same endpoints, so its
pages are a working reference for every flow in Part A.

## API availability

| Area | Status |
|---|---|
| Everything in Part A (auth incl. account deletion and signed-in devices, curriculum, study, exams, results incl. overview, plans, coupons, health) | ✅ Available — integrate now |
| Notifications and study reminders (A9) | ✅ Available — integrate now |
| Push notifications (A10) | ✅ Available — integrate now (needs the app id change in A10) |
| AI analysis, AI tutor, courses | V2 — not in V1 |

When a Part B module becomes available, its section here is updated and its
flag can be turned on.

This replaces the old `*_API_REQUIREMENTS.md` files at the repo root, which
were written before the API existed. Delete them once the integration
lands, except the AI and course ones, which stay as V2 input.

**Scope: V1.** AI analysis, AI tutor and courses/video lessons are V2 and are
not part of this contract (see "Out of scope — V2").

---

## 0. Global changes (do these first)

| # | Area | Change | File(s) |
|---|---|---|---|
| G1 | Base URL | Dev: `http://localhost:3001/api/v1` (iOS simulator) / `http://10.0.2.2:3001/api/v1` (Android emulator). Preview/staging: `https://kasbana.net/api/v1` (the website proxies `/api` to the API). | `env/*.json`, `app_config.dart` default |
| G2 | Error envelope | API errors: `{ statusCode, error, message: string \| string[], code?, details?, path, timestamp }`. **No `requestId`.** Add `code` and `details` to `ApiException` and drop `requestId`. Map `code` to localized messages in `failure_messages.dart`. | `api_exception.dart`, `api_client.dart`, `core/error/*` |
| G3 | Pagination | Lists return `{ data: T[], meta: { page, limit, total, totalPages } }`. Query `page` (≥1) and `limit` (1–100, default 20). There is no `offset`. Add a shared `Paginated<T>` model; "has more" means `page < totalPages`. | new `core/network/paginated.dart` |
| G4 | Unknown fields | The API rejects **any** unknown body or query field with `400`. Send only the fields listed here. | all remote data sources |
| G5 | Auth retry rule | `AuthInterceptor` currently skips refresh-and-retry for every `/auth/` path. Skip it **only** for `/auth/login`, `/auth/register`, `/auth/refresh`, `/auth/logout` and `/auth/password-reset/*`. `/auth/me`, `/auth/change-password` and `/auth/sessions*` must refresh and retry like any other call. | `auth_interceptor.dart` |
| G6 | Enums | API enums are UPPER_SNAKE: `EASY/MEDIUM/HARD`, `IMMEDIATE/DEFERRED`, `IN_PROGRESS/PAUSED/COMPLETED`, `SUBMITTED/EXPIRED`, `STUDY/EXAM`, `USER/ADMIN`. Map them in the data layer only. | models |
| G7 | Language | Curriculum, questions and choices are **single-language** (as authored). There is no `locale` parameter on existing endpoints. Show text as-is; UI chrome stays localized. Notification texts are the exception: they come in English or Arabic based on the `Accept-Language` header (see A9). | `api_client.dart` |
| G8 | Entitlement | `403` with message `An active subscription is required` (or `No active subscription covers one or more selected topics`) comes back when **starting** a study session or exam. Map it to a "no access" failure that opens the Plans screen. | `failure_mapper.dart` |
| G9 | Rate limits | `429` limits: login 10/min, register 5/min, password reset request 3/min, reset confirm 5/min, change password 5/min, coupon validate 10/min, coupon redeem 5/min, study and exam creation 20 per 10 min. | — |

Error `code` values the app should translate: `WRONG_CURRENT_PASSWORD`,
`SAME_PASSWORD`, `NOT_FOUND`, `COUPON_INVALID`, `COUPON_NOT_ACTIVE`,
`COUPON_WRONG_PLAN`, `COUPON_EXHAUSTED`, `COUPON_ALREADY_USED`,
`COUPON_NOT_FREE`, `PLAN_UNAVAILABLE`, `REMINDER_LIMIT_REACHED`
(`details.max`) and `INVALID_CUSTOM_DAYS`. Show the
generic message for any code the app does not know.

---

# Part A — existing endpoints (frozen)

## A1. Auth

The refresh token is **not** in the response body. The API sets it as a
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

| Mobile today | API (use this) | Request | Response |
|---|---|---|---|
| `POST /auth/register` | same | `{ email (≤254), password (8–200), firstName (1–100), lastName (1–100) }` | `201` `{ accessToken }` + cookie. `409` "Email already in use" |
| `POST /auth/login` | same | `{ email, password }` | `200` `{ accessToken }` + cookie. `401` on bad credentials |
| `POST /auth/refresh` body `{refreshToken}` | `POST /auth/refresh`, **no body**, header `Cookie: refresh_token=…` | — | `200` `{ accessToken }` + **new** cookie. `400` "Missing refresh token", `401` "Invalid refresh token" |
| `POST /auth/logout` body `{refreshToken}` | `POST /auth/logout`, no body, `Cookie` header | — | `204` |
| `POST /auth/forgot-password` | `POST /auth/password-reset/request` | `{ email }` | `200` `{ message }` (always, even for unknown emails) |
| `POST /auth/reset-password` | `POST /auth/password-reset/confirm` | `{ token, newPassword (8–200) }` | `200` `{ message }`. **All sessions are revoked**, so send the user to Login |
| `GET /users/me` | `GET /auth/me` | — | `200` `{ id, email, firstName, lastName, role }` |
| `PATCH /users/me` | same | `{ firstName?, lastName? }` | `200` `{ id, email, firstName, lastName, role, isActive, createdAt, updatedAt }` |
| *(none)* | `POST /auth/change-password` | `{ currentPassword, newPassword (8–200) }` | `200` `{ accessToken }` + new cookie (other devices are signed out). `400` code `WRONG_CURRENT_PASSWORD`; `400` code `SAME_PASSWORD` when the new password equals the current one |
| *(none)* | `GET /auth/sessions` | — | `200` `[{ id, userAgent, ipAddress, lastActiveAt, expiresAt, current }]`, most recent first |
| *(none)* | `DELETE /auth/sessions/:id` | — | `204`. `404` code `NOT_FOUND` for an unknown or already signed-out session |
| *(none)* | `POST /auth/sessions/revoke-others` | — | `200` `{ "revoked": 2 }`. `400` code `SESSION_UNKNOWN` (rare: sign in again) |
| *(none)* | `DELETE /users/me` | `{ password }` | `204`. `400` code `WRONG_CURRENT_PASSWORD`; `403` code `ADMIN_SELF_DELETE` for admin accounts; `429` after 5 tries a minute |

⚠️ **`GET /users/me` does not exist.** The request falls into the admin-only
`GET /users/:id` route and returns **403** for every student. Load the profile
with `GET /auth/me`. Only `PATCH /users/me` and `DELETE /users/me` live under `/users/me`.

**Signed-in devices (`/auth/sessions`).** One row per device where the
student is signed in; `current` marks this device. `lastActiveAt` is the
device's last sign-in or token refresh. A session's `id` changes each time
that device refreshes its token, so always delete using the id from a fresh
list. Signing a device out (one, or "all others") ends it **immediately**:
that device's next request gets `401`, its refresh gets `401`, and it lands
on Login. The same happens to the current device after logout, and to other
devices after a password change.

**Account deletion (`DELETE /users/me`).** Required in-app by the App Store
and Google Play for apps that offer sign-up. The account is anonymised and
deactivated on the server: the email is freed (the person can register
again), every session ends at once (the current access token stops working
too), and study history stays only as anonymous statistics.

**Mobile changes**
- `AuthResponseModel`: only `accessToken` comes from the body, and
  `refreshToken` comes from the cookie. Register, login and refresh return
  **no user**, so call `GET /auth/me` right after (also in `restoreSession`).
- `UserProfileModel` / `AuthUser`: `roles: List<String>` becomes
  `role: String` (`USER` | `ADMIN`); `isAdmin => role == 'ADMIN'`.
- Add a Change Password screen and remove it from the "blocked" table
  in `features/auth/README.md`. After success, save the new access token and
  the new `refresh_token` cookie (the old one is revoked).
- Add a **Signed-in devices** screen under Profile: list `GET /auth/sessions`
  (show `userAgent` as the device name, `lastActiveAt`, a "This device" badge
  for `current`), a "Sign out" action per other device
  (`DELETE /auth/sessions/:id`, then reload the list), and "Sign out all other
  devices" (`POST /auth/sessions/revoke-others`). Signing out `current` from
  here equals logging out. Remove "Session / device management" from the
  blocked table in `features/auth/README.md`.
- When a refresh returns `401` (for example because this device was signed
  out from another one), clear the local session and go to Login; this is the
  existing `onSessionExpired` path.
- Add **Delete account** to Profile: a confirmation screen that explains it
  cannot be undone and asks for the password, then `DELETE /users/me`. On
  `204`, clear the local session (tokens, cached data, scheduled local
  reminders) and go to Login. Do **not** call `/auth/logout` afterwards, since
  the session is already gone. Once push ships (Part B), call
  `POST /devices/unregister` **before** the delete. Remove "Account deletion"
  from the "blocked" table and the comment in `profile_screen.dart`.
- Validators: password 8–200, names 1–100, email ≤254.
- Password reset emails are not sent yet, so the reset flow cannot be
  completed end to end for now. Build it against the endpoints anyway.

## A2. Curriculum

Students see published nodes only. There is **no entitlement check on
browsing**: every signed-in user can browse every published program.

**Recommended:** one call per program instead of five levels.

| Mobile today | API (use this) |
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
- `ProgramModel`: **remove `code`** (today a required cast, so it crashes;
  `programs_screen.dart` only uses it for the avatar letter, so use the first
  letter of `name` instead)
  and remove `imageUrl`. `isActive` becomes `isPublished`.
- All models: ids are UUIDs, and `name` / `description` are single-language.
- Parse the `{ data, meta }` lists (G3). Prefer the tree endpoint and build the
  Part → Unit → Sub-unit → Topic screens from it in memory.
- Use `questionCounts.PUBLISHED` to disable topics that have no questions.
- Default program: the first item from `GET /entitlements/me` (see A6).

## A3. Study sessions

| Mobile today | API (use this) |
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

Reveal rule: while the session is not completed, a question is revealed
only when it has been answered **and** `feedbackMode = IMMEDIATE`. Once
`status = COMPLETED`, **every** question is revealed, skipped ones included.
Revealed questions carry `question.explanation` and `choices[].isCorrect`;
`isCorrect` is `true`/`false` for answered questions and stays `null` for
skipped ones.

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
| re-answer after feedback | the API allows it. **Lock it on the client**: locked if `status != IN_PROGRESS` or (`IMMEDIATE` and `answeredAt != null`) |
| `POST …/submit` | `POST …/complete`; on `400` "already completed", `GET` the session and continue |
| `SessionResult` | derived (see table below) |
| review list | built from the completed session. Every question, skipped ones included, has its correct choice (`choices.firstWhere(c.isCorrect).id`) and explanation; a skipped question has `selectedChoiceId: null` and `isCorrect: null` |
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

| Mobile today | API (use this) |
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
| "clear answer" | not supported by the API; remove the action |
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

| Mobile today | API (use this) |
|---|---|
| `GET /performance/topics?attemptType` | `GET /results/performance/topics?type=STUDY\|EXAM` (`type` optional; omitted = both) |
| `GET /performance/attempts?attemptType&limit&offset` | `GET /results/history?page&limit&type=STUDY\|EXAM` (`type` optional) |
| `GET /performance/attempts/:id` | `GET /study/sessions/:id` or `GET /exams/attempts/:id`, chosen by `type` |
| `GET /performance/overview?attemptType` | `GET /results/overview?type=STUDY\|EXAM` (see below) |
| — | `GET /results/performance/parts?type=STUDY\|EXAM` (`type` optional) |
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

`type` is the only accepted value set (`STUDY` or `EXAM`). Any other value
returns `400`. With `type`, `meta.total` counts only that type, so paging is
exact.

Overview (`GET /results/overview`):

```json
{ "totalAttempts": 12, "inProgressAttempts": 1, "questionsPracticed": 240,
  "totalAnswered": 220, "totalCorrect": 168, "accuracy": 76.4,
  "scorePercent": 70.0, "totalTimeSeconds": 9300, "avgTimeSeconds": 42 }
```

Every number counts **finalised** attempts only (study `COMPLETED`, exam
`SUBMITTED` or `EXPIRED`); `inProgressAttempts` counts the rest.
`questionsPracticed` = questions served (unanswered included),
`accuracy` = correct ÷ answered, `scorePercent` = correct ÷ questions
practiced (one decimal each). `accuracy`, `scorePercent` and `avgTimeSeconds`
are `null` when there is nothing to divide by. An exam whose time ran out
counts as in progress until it is next opened (the server marks it `EXPIRED`
on read). Topic and part performance also count answers from in-progress
`IMMEDIATE` study sessions, so their totals can be a little higher than the overview's.

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
| in-progress attempts in history | history includes them: show them as "Resume" rows, or filter out `finalizedAt == null` |
| `attemptType` filter (`AttemptTypeFilter`) | send `type=STUDY` / `type=EXAM` on history, overview, topics and parts; `all` sends no `type` |
| `limit/offset`, `{items, hasMore}` | `page/limit`, `{ data, meta }` |
| attempt details | fetch the session or attempt and reuse the A3/A4 derivations and topic grouping |
| `PerformanceOverview` | from `GET /results/overview`: `totalAttempts`, `questionsPracticed`, `totalAnswered`, `totalCorrect`, `overallScorePercent = scorePercent ?? 0`, `totalTime = totalTimeSeconds`, `averageTimePerQuestion = avgTimeSeconds ?? 0`. Best and weak topics still come from `performance/topics` |

The local attempts store (`performance_local_data_source.dart`,
`local_attempts_provider.dart`) becomes unnecessary once history comes from
the server. Keep it only as an offline cache.

## A6. Plans, access and coupons (new screens)

| Endpoint | Response |
|---|---|
| `GET /entitlements/me` | `[{ id, userId, programId, subscriptionId, startsAt, expiresAt, revokedAt, createdAt, program: { id, name } }]`, active only, soonest expiry first |
| `GET /subscriptions/me` | `[{ id, userId, planId, status: ACTIVE\|CANCELLED, source: PAYMENT\|ADMIN\|COUPON, startsAt, endsAt, cancelledAt, createdAt, updatedAt, plan: { id, name, programId }, entitlement: { startsAt, expiresAt, revokedAt } \| null }]` |
| `GET /plans` (public) | `[{ id, programId, name, description, priceCents, currency, durationDays, isActive, createdAt, updatedAt, program: { id, name } }]`, cheapest first |
| `POST /coupons/validate` `{ code (3–40), planId }` | `200` `{ code, planId, currency, priceCents, amountOffCents, finalPriceCents }` |
| `POST /coupons/redeem` `{ code, planId }` | `201` `{ redemption, subscription }`. Works only when the final price is 0; otherwise `400 COUPON_NOT_FREE` |

Prices are in minor units (cents). Online payment is **not available yet**. Show paid plans as "contact us" or
coupon-only; never fake a checkout.

Mobile work: build `features/subscription` (Plans & access screen, coupon
entry) and gate the Study and Exam setup CTAs on `GET /entitlements/me`
being non-empty.

## A7. Health

`GET /health` (public) returns `200` with `database: "ok"`, or `503`. It is
optional, for a "server unreachable" banner.

## A8. API features the app does not use yet (to build in the app)

These endpoints already work (the website uses them). The sections above
give the shapes; this is the checklist of screens and behaviour the app still
needs. The website page in the last column shows a working flow.

| # | Feature | Endpoints | Website page (`kasbana.net…`) |
|---|---|---|---|
| B1 | Change password | `POST /auth/change-password` (A1) | `/account` |
| B2 | Delete account | `DELETE /users/me` (A1) | — |
| B2b | Signed-in devices | `GET /auth/sessions`, `DELETE /auth/sessions/:id`, `POST /auth/sessions/revoke-others` (A1) | — |
| B3 | Plans, access, coupons — `features/subscription` | `GET /plans`, `GET /entitlements/me`, `GET /subscriptions/me`, `POST /coupons/validate`, `POST /coupons/redeem` (A6) | `/plans`, `/dashboard` |
| B4 | Resume unfinished study sessions and exams | `GET /study/sessions`, `GET /exams/attempts`, `GET /results/history` (rows with `finalizedAt: null`) | `/dashboard`, `/results` |
| B5 | Pause / resume a study session | `PATCH /study/sessions/:id/pause`, `/resume` (A3) | `/study/<id>` |
| B6 | Server-side flags | `PATCH …/questions/:questionId/flag` `{ flagged }` (A3, A4) | `/study/<id>`, `/exam/<id>` |
| B7 | Richer setup: several topics, "all my topics" (omit `topicIds`), difficulty, any count 1–100 | `POST /study/sessions`, `POST /exams/attempts` (A3, A4) | `/study`, `/exam` |
| B8 | Performance by part and a 7-day trend chart | `GET /results/performance/parts`, `GET /results/performance/trend` (A5) | `/dashboard` |
| B9 | Curriculum tree in one call; disable topics with no questions | `GET /curriculum/programs/:id/tree` (A2) | `/learn` |
| B10 | Show the question reference | `question.code`, `question.losCode` in study/exam payloads (A3) | `/study/<id>` |

---

## A9. Notifications and study reminders

Flag: `NOTIFICATIONS_API_AVAILABLE` (covers both). Every route needs the
bearer token; everything is scoped to the signed-in student.

### Notification object

```json
{ "id": "…", "type": "PERFORMANCE_UPDATE", "priority": "NORMAL",
  "title": "Study session complete", "body": "You got 14 of 20 correct (70%).",
  "action": { "type": "OPEN_ATTEMPT", "targetId": "<session id>", "attemptType": "STUDY" },
  "isRead": false, "readAt": null, "createdAt": "2026-10-08T08:00:00.000Z" }
```

- `type`: `STUDY_REMINDER | EXAM_REMINDER | PERFORMANCE_UPDATE | ACHIEVEMENT | SYSTEM`.
  New types may appear later: an unknown `type` must **not** throw (show it
  as a plain notice).
- `priority`: `LOW | NORMAL | HIGH`.
- `action` is `null` or `{ type, targetId?, attemptType? }` — see the action
  table below. An unknown `action.type` falls back to showing the details.
- `title` and `body` are display-ready text in **English or Arabic**, chosen
  by the `Accept-Language` header the app sends: `ar` (or `ar-SA`, …) →
  Arabic, anything else or no header → English. Send the app's current
  language on every notifications call, and refetch the list when the user
  switches language.

What creates notifications today: finishing a study session, and submitting
an exam or running out of time on one, create a `PERFORMANCE_UPDATE` that
opens the attempt. A score of at least 80% on 10 or more questions also
creates an `ACHIEVEMENT` that opens Performance. Each respects the
student's preferences.

### Notification endpoints

| Method & path | Request | Response |
|---|---|---|
| `GET /notifications` | `page`, `limit`, `unreadOnly?=true`, `type?` (repeat for several: `?type=STUDY_REMINDER&type=EXAM_REMINDER`) | `200` `{ data: Notification[], meta }`, newest first |
| `GET /notifications/unread-count` | — | `200` `{ "count": 3 }` |
| `GET /notifications/:id` | — | `200` Notification |
| `PATCH /notifications/:id/read` | **no body** | `200` Notification (calling it again keeps the first `readAt`) |
| `POST /notifications/read-all` | — | `200` `{ "updated": 5 }` |
| `DELETE /notifications/:id` | — | `204` |
| `GET /notifications/preferences` | — | `200` all seven toggles (all `true` until changed) |
| `PATCH /notifications/preferences` | any subset of the seven toggles | `200` all seven toggles |

The seven toggles: `studyReminders`, `dailyStudyReminders`, `examReminders`,
`simulationReminders`, `performanceUpdates`, `achievements`,
`systemNotifications`. `dailyStudyReminders` and `simulationReminders` are
for the app's own local reminders; the app applies them on the device.

Errors: `404` code `NOT_FOUND` for an unknown id (or one that belongs to
someone else); `400` for an id that is not a UUID, an unknown `type`, or any
unknown body field (for example `aiRecommendations`).

### Study reminder object and endpoints

Reminders **fire on the device** as local notifications; the API only stores
them so they sync across devices and survive a reinstall. Max **20** per
student, so the list is a plain array (not paginated).

```json
{ "id": "…", "title": "Daily CMA practice", "enabled": true, "hour": 7, "minute": 30,
  "repeat": "EVERY_DAY", "customDays": [], "notificationType": "STUDY_REMINDER",
  "createdAt": "…", "updatedAt": "…" }
```

| Method & path | Request | Response |
|---|---|---|
| `GET /study-reminders` | — | `200` `Reminder[]`, ordered by `hour`, `minute` |
| `POST /study-reminders` | `{ title (1–100), enabled? (default true), hour (0–23), minute (0–59), repeat, customDays?, notificationType? }` | `201` Reminder |
| `PATCH /study-reminders/:id` | any subset of the create fields (the on/off switch sends `{ "enabled": false }` alone) | `200` Reminder |
| `DELETE /study-reminders/:id` | — | `204` |

- `repeat`: `ONE_TIME | EVERY_DAY | WEEKDAYS | WEEKENDS | CUSTOM`.
- `customDays`: unique `MON`…`SUN`; required (non-empty) for `CUSTOM`, empty
  for every other `repeat`. Changing `repeat` away from `CUSTOM` without
  sending `customDays` clears them.
- `notificationType`: `STUDY_REMINDER` (default) or `EXAM_REMINDER`.
- `hour`/`minute` are **device local time**. A `ONE_TIME` reminder fires at
  the next `hour:minute`; the app then sends `{ "enabled": false }`.

Errors: `400` code `REMINDER_LIMIT_REACHED` with `details.max = 20` when
creating a 21st; `400` code `INVALID_CUSTOM_DAYS` when the days rule is
broken; `404` code `NOT_FOUND` for an unknown id.

### App changes

| Area | Change |
|---|---|
| List | Parse `{ data, meta }` (was a plain array); load more pages on scroll |
| Filter chips | Study → `type=STUDY_REMINDER&type=EXAM_REMINDER`, Performance → `type=PERFORMANCE_UPDATE&type=ACHIEVEMENT`, System → `type=SYSTEM`, Unread → `unreadOnly=true`; drop the in-memory filter and the AI chip (V2) |
| Details | Use the loaded item, or `GET /notifications/:id` when it is not loaded (deep links, push taps later) |
| Mark read | `PATCH …/read` with **no body** (today it sends `{isRead: true}`) |
| Item model | Add `readAt`; `action` may be `null`; read `attemptType` for `OPEN_ATTEMPT`; unknown `type` must not throw |
| Language | Send `Accept-Language: ar` or `en` (the app's current language) on `/notifications` calls — simplest is to set it on every request in `ApiClient`; other endpoints ignore it |
| Preferences | 7 keys: remove `aiRecommendations` (sending it returns `400`) and hide its toggle; `PATCH` may send only the changed keys |
| Reminders | Parse `updatedAt`; show `REMINDER_LIMIT_REACHED` / `INVALID_CUSTOM_DAYS` messages; replace the mock scheduler with real local notifications and reschedule all reminders after login, after each sync and on app start |
| Account deletion | Cancel all scheduled local reminders on the device (the API deletes the stored ones) |

---

## A10. Push notifications

Flag: `PUSH_API_AVAILABLE`. Push uses **Firebase Cloud Messaging** (it also
delivers to iOS through APNs). Every notification in A9 is also sent as a
push to the student's registered phones; the inbox (A9) stays the source of
truth.

**Status (2026-10-09): sections 1 and 2 are already done in the project**
— app id `com.madeen.app` on Android and iOS, `google-services.json`,
`GoogleService-Info.plist` (in the Runner target), the Google services Gradle
plugin, `firebase_core` + `firebase_messaging`, `lib/firebase_options.dart`,
`Firebase.initializeApp` in `main.dart`, the Android 13+ notification
permission and iOS *Background Modes → Remote notifications*. Still to do:
the iOS **Push Notifications** capability in Xcode (needs the team's Apple
account), asking for permission at runtime, and sections 3–4.

### 1. Change the app id to `com.madeen.app` (first)

The Firebase project (`madeen-4d6a9`) has the Android and iOS apps registered
as **`com.madeen.app`**, and the app id can't change after the first store
release, so change it now:

- Android: `android/app/build.gradle(.kts)` → `applicationId` (and
  `namespace`, if present) = `com.madeen.app`. Move `MainActivity` to the
  matching package folder if the namespace changes.
- iOS: Xcode → Runner target → Signing & Capabilities → Bundle Identifier =
  `com.madeen.app`; RunnerTests → `com.madeen.app.RunnerTests`.

### 2. Connect Firebase

- In the project folder: `flutterfire configure --project=madeen-4d6a9`
  (pick android and ios). It writes `lib/firebase_options.dart`,
  `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
  (added to the Runner target). **Don't commit them**: they hold the Firebase
  API keys and are git-ignored. The app reads its Firebase options at build
  time from a git-ignored `env/firebase.json` (copy
  `env/firebase.example.json`, fill it from the Firebase console) and builds
  with `--dart-define-from-file=env/dev.json --dart-define-from-file=env/firebase.json`.
  Without it, the app runs without push.
- Packages: `firebase_core`, `firebase_messaging`.
- Skip the native setup steps the Firebase console shows (Gradle snippets,
  Swift Package Manager, `FirebaseApp.configure()`); FlutterFire handles them.
- iOS: Xcode → Runner → **Push Notifications** capability and **Background
  Modes → Remote notifications**. iOS pushes also need the APNs key uploaded
  in Firebase → Project settings → Cloud Messaging (account owner).
- Android 13+: ask for the notification permission (`POST_NOTIFICATIONS`)
  before registering; iOS: `requestPermission()`.

### 3. Endpoints

| Method & path | Request | Response |
|---|---|---|
| `POST /devices` | `{ token: string (1–4096), platform: "IOS" \| "ANDROID", locale?: "en" \| "ar" }` | `201` `{ id, platform, createdAt }` |
| `POST /devices/unregister` | `{ token }` | `204` (always, even if unknown) |

- **Register** after sign-in, on every app start while signed in, on
  `onTokenRefresh`, and when the user changes the app language (send the new
  `locale`; pushes are written in it). Registering again is safe: the same
  token is updated, not duplicated, and a token used by a previous account on
  the same phone moves to the current one.
- **Unregister** on logout **before** `POST /auth/logout` (logout itself can't
  remove the token), and before `DELETE /users/me`.
- Unknown fields → `400`; no token → `401`.

### 4. Receiving a push

- `notification.title` / `notification.body`: display-ready text in the
  device's `locale`.
- `data`: `{ notificationId, type, action }` — all strings; `action` is JSON
  (`{"type":"OPEN_ATTEMPT","targetId":"…","attemptType":"STUDY"}`) or `"null"`.
- On tap (foreground, background or from terminated): parse `action` and
  route through the same resolver as the inbox (A9); with `"null"` or an
  unknown action, open `GET /notifications/:notificationId`. Mark it read
  with `PATCH /notifications/:id/read` when shown.
- In the foreground, refresh the unread badge (`GET /notifications/unread-count`)
  instead of showing a system banner, or show an in-app banner.

### App changes

| Area | Change |
|---|---|
| App id | `com.madeen.app` on Android and iOS (section 1) |
| Firebase | `flutterfire configure`, packages, iOS capabilities, permissions (section 2) |
| `PushNotificationHandler` | Replace the mock: get the FCM token, `POST /devices`, listen to `onTokenRefresh`, `POST /devices/unregister` on logout and account deletion |
| Tap handling | `onMessageOpenedApp` + `getInitialMessage` → route by `data.action` |
| Flags | Add `PUSH_API_AVAILABLE` to `AppConfig` and every `env/*.json` |

---

# Part B — endpoints not available yet

None: every endpoint the app needs in V1 is available.

Notification `action.type` renames (for A9):

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

**AI analysis, AI tutor and courses/video lessons are V2.** Their APIs do
not exist in V1, and the mobile app does not integrate them now:

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
2. A1 auth, including Change Password and Delete Account.
3. A2 curriculum.
4. A6 access check (needed so Study and Exam can show "no access").
5. A3 study sessions.
6. A4 exams.
7. A5 performance (replaces local attempt recording; uses `/results/overview` and the `type` filter).
8. A9 notifications and study reminders.
9. The remaining A8 items.
10. A10 push notifications (change the app id first).

**Definition of done for each step:** the app only calls paths listed in
this document, sends only the listed fields (unknown ones are rejected with
`400`), parses the listed response shapes, and works against the API with
the module flag on. A module is ready to integrate when it does this.

For each step: switch the module's `*_API_AVAILABLE` flag on in `env/dev.json`,
update `test/features/<module>` fixtures to the shapes above, and run against
the API with the test student account (`student@madeen.dev` / `Password123!`).
