# Notifications & Study Reminders API — required backend contract (not yet implemented)

**Status as of Phase 8 (mobile): these endpoints do not exist on the
backend.** Verified by inspection — `backend/src/modules/` currently
contains only `identity` and `notification` (a transactional email/SMS
dispatch module — a different concern from this document; see
`docs/ARCHITECTURE.md` §3 for the module table). This document is the
mobile app's proposed contract for an in-app Notification Center and Study
Reminders, written so whoever implements the backend module can do so
without reading Flutter code. It mirrors the style of `docs/API_AUTH.md`
and `mobile/PERFORMANCE_ANALYTICS_API_REQUIREMENTS.md`.

Until this exists, the mobile app runs entirely on a deterministic
in-memory mock — see "Current mobile-side status" at the bottom. **Do not
treat this document as an existing API** — no backend code has been
written to match it, and the exact endpoint paths below are a proposal,
matching what `notifications_remote_data_source.dart` already calls, not a
confirmed contract.

**PROPOSED / BACKEND DEPENDENCY — every endpoint in this document.**

## Authentication

Every endpoint below requires the same authenticated-user access as the
rest of the app (bearer access token, per `docs/API_AUTH.md`). There is no
`userId` parameter anywhere in this contract — every response is implicitly
scoped to the authenticated caller, same rule as every other feature
contract in this directory.

## Timestamp format

Every timestamp on the wire (`createdAt`, a Study Reminder's `createdAt`)
is ISO-8601 UTC (e.g. `"2026-09-25T08:00:00.000Z"`), parsed with
`DateTime.parse` on the client — same convention as every other feature.

## Pagination

**None of these endpoints paginate.** `GET /notifications` and
`GET /study-reminders` both return a plain JSON array. At this feature's
expected volume (a personal notification/reminder list, not a shared feed)
the mobile client keeps the full list in memory
(`NotificationsListState`/`StudyRemindersState`, both a flat
`Loading`/`Ready(List)`/`Error`, no `loadMore`) — see
`notifications_list_state.dart` and `study_reminders_state.dart`. If volume
ever grows enough to need it, adding `limit`/`offset` (matching
`GET /performance/attempts`'s own pagination) is an additive change; it is
explicitly out of scope for this phase.

## Notification types

Wire values for a notification's `type` (`NotificationType.toWire()` /
`.fromWire()` in `domain/entities/notification_type.dart`):

| Wire value           | Meaning                                            |
| --------------------- | --------------------------------------------------- |
| `STUDY_REMINDER`      | A scheduled Study Reminder fired                    |
| `EXAM_REMINDER`       | A scheduled reminder typed for exam prep            |
| `PERFORMANCE_UPDATE`  | New Performance Analytics data is worth a look      |
| `AI_RECOMMENDATION`   | A new AI Analysis recommendation is ready           |
| `ACHIEVEMENT`         | A milestone (streak, completion count) was reached  |
| `SYSTEM`              | Account/app notice unrelated to study activity      |

An unrecognized wire value is a `FormatException` on this client today
(`NotificationType.fromWire`'s `default` case) — unlike
`NotificationActionType` (see below), the type list is not expected to grow
without a client update, since it also drives which `NotificationPreferences`
toggle gates it.

Priority (`priority`): `LOW` | `NORMAL` | `HIGH`
(`NotificationPriority.toWire()`/`.fromWire()`). Communicated to the
student as a small "Important" label, never color alone.

## Action / deep-link payload

A notification may carry an `action` object so the mobile client can offer
a "primary CTA" that navigates somewhere relevant:

```json
"action": { "type": "openAttemptDetails", "targetId": "perf-attempt-2" }
```

`type` — one of (`NotificationActionType.toWire()` /
`domain/entities/notification_action.dart`):

| Wire value                | Needs `targetId`? | Resolves to (client-side)                    |
| -------------------------- | ------------------ | --------------------------------------------- |
| `openStudySessionSetup`    | yes (a topicId)    | Study Session Setup for that topic            |
| `openExamSetup`             | no                  | Exam Simulation Setup                         |
| `openPerformanceOverview`  | no                  | Performance Overview                          |
| `openTopicPerformance`     | no*                 | Topic Performance list (see note)             |
| `openAttemptDetails`       | yes (an attemptId) | that attempt's Attempt Details                |
| `openAiAnalysisOverview`   | no                  | AI Analysis Overview                          |
| `openAiAnalysisTopic`      | yes (a topicId)    | that topic's AI Insight                       |
| `openAiAnalysisAttempt`    | yes (an attemptId) | that attempt's AI Insight                     |
| `none`                     | —                   | no action (a plain notice)                    |

\* `openTopicPerformance` never needed a `targetId` on the client because
no per-topic Performance route exists yet — it always resolves to the
Topic Performance list, not one topic's detail. A backend-sent `targetId`
for it is accepted but currently ignored by
`NotificationActionResolver` (`presentation/navigation/
notification_action_resolver.dart`).

Every mapping above lives in exactly one place —
`NotificationActionResolver` — never scattered across screens. A wire
value this client build doesn't recognize decodes to
`NotificationActionType.unknown` (never an exception — see
`NotificationActionType.fromWire`'s `default` case) and resolves to `null`
(no CTA shown; the student can still read the notification's own title/
body), so a client running behind a future backend release that added a
new action type degrades gracefully instead of crashing.

## Error responses

The standard envelope from `docs/API_AUTH.md`:
`{statusCode, message, error, path, timestamp, requestId}`. `401` per the
normal auth rules, `404` for an unknown/inaccessible notification or
reminder id, `500` on server error. Every endpoint below is otherwise
read/write on the caller's own data only — no cross-user access is ever
valid, so a `404` (not a `403`) is correct for "exists, but not yours" too,
matching the anti-enumeration posture `PERFORMANCE_ANALYTICS_API_
REQUIREMENTS.md` already documents for attempt ids.

## Endpoints

All under the existing `/api/v1` prefix.

### `GET /api/v1/notifications`

Returns every notification for the authenticated user, most-recent-first.

**Response `200`:**

```json
[
  {
    "id": "notif-1",
    "title": "Continue your CMA preparation",
    "body": "You have not practiced Financial Reporting recently.",
    "createdAt": "2026-09-25T08:00:00.000Z",
    "type": "STUDY_REMINDER",
    "isRead": false,
    "priority": "NORMAL",
    "action": { "type": "none" }
  }
]
```

`priority` and `action` may be omitted; the client defaults them to
`NORMAL` / `{"type": "none"}` respectively
(`NotificationItemModel.fromJson`).

### `GET /api/v1/notifications/unread-count`

Cheap enough to poll independently of the full list — the mobile client
calls this to refresh Home's badge without re-fetching everything (see
`unreadNotificationCountProvider`).

**Response `200`:** `{ "count": 3 }`

### `PATCH /api/v1/notifications/:id/read`

**Request body:** `{ "isRead": true }`

**Response `200`:** no body required (the client discards it).
`404` for an unknown `id`.

### `POST /api/v1/notifications/read-all`

Marks every notification for the authenticated user as read.

**Response `200`:** no body required.

### `DELETE /api/v1/notifications/:id`

**Response `200`/`204`:** no body required. `404` for an unknown `id`.

### `GET /api/v1/notifications/preferences`

Returns the authenticated user's per-category toggle state.

**Response `200`:**

```json
{
  "studyReminders": true,
  "dailyStudyReminders": true,
  "examReminders": true,
  "simulationReminders": true,
  "performanceUpdates": true,
  "aiRecommendations": true,
  "achievements": true,
  "systemNotifications": true
}
```

Every field is required in the response; there is no partial/omitted-field
shape (`NotificationPreferencesModel.fromJson` reads every key as
non-nullable). A first-time user with no saved preferences should receive
this same shape with the defaults above (all `true`), not a `404`.

### `PATCH /api/v1/notifications/preferences`

**Request body:** the full preferences object (same shape as the `GET`
response above) — the client always sends the complete, already-merged
object (see `NotificationPreferencesNotifier.setPreferences`'s optimistic
update), never a partial patch of individual fields.

**Response `200`:** no body required.

### `GET /api/v1/study-reminders`

**Response `200`:**

```json
[
  {
    "id": "reminder-1",
    "title": "Daily CMA Practice",
    "enabled": true,
    "hour": 7,
    "minute": 30,
    "repeat": "EVERY_DAY",
    "customDays": [],
    "notificationType": "STUDY_REMINDER",
    "createdAt": "2026-09-01T07:30:00.000Z"
  }
]
```

`repeat` — one of `ONE_TIME` | `EVERY_DAY` | `WEEKDAYS` | `WEEKENDS` |
`CUSTOM` (`ReminderRepeat.toWire()`). `customDays` — an array of `MON`..
`SUN` (`Weekday.toWire()`), only meaningful (and only ever non-empty) when
`repeat` is `CUSTOM`. `notificationType` — `STUDY_REMINDER` (the default)
or `EXAM_REMINDER`, so a reminder respects that category's own
`NotificationPreferences` toggle rather than always the study one.

### `POST /api/v1/study-reminders`

**Request body:** same shape as a reminder above minus `id`/`createdAt`
(the backend assigns both):

```json
{
  "title": "Daily CMA Practice",
  "enabled": true,
  "hour": 7,
  "minute": 30,
  "repeat": "EVERY_DAY",
  "customDays": [],
  "notificationType": "STUDY_REMINDER"
}
```

**Response `201`:** the full reminder object (with `id`/`createdAt`
assigned).

### `PATCH /api/v1/study-reminders/:id`

Used both for a full edit (same body shape as `POST`, from the Study
Reminder Editor) and for the reminders list's one-tap enable/disable
switch (body `{ "enabled": false }` only). **Response `200`:** the full,
updated reminder object. `404` for an unknown `id`.

### `DELETE /api/v1/study-reminders/:id`

**Response `200`/`204`:** no body required. `404` for an unknown `id`.

## Local (on-device) notification status

**No implementation of `NotificationScheduler`
(`domain/services/notification_scheduler.dart`) schedules a real OS-level
notification in this phase.** `MockNotificationScheduler`
(`data/services/mock_notification_scheduler.dart`) only records which
reminder ids are "scheduled" in memory, so the Study Reminders UI has
something truthful to reflect. Wiring a real plugin (e.g.
`flutter_local_notifications`, handling exact-alarm/notification
permissions on Android 13+ and iOS's own authorization prompt) is future
work — the abstraction is already in place so that work touches exactly
one new implementation class, never a screen or the repository. Do not
present Study Reminders as delivering a real device notification to a
user or reviewer until a real implementation replaces the mock.

## Push notification status

**No push provider (FCM/APNs) is configured, and no backend endpoint
exists to register a device token.** `PushNotificationHandler`
(`domain/services/push_notification_handler.dart`) /
`MockPushNotificationHandler` (`data/services/
mock_push_notification_handler.dart`) exist only so a future real
implementation's call sites compile against something today —
`registerDevice()` always returns `null`. This is future backend/device
integration work, out of scope for this phase.

## Current mobile-side status

The mobile app already has the full client-side abstraction ready for this
contract:

- `lib/features/notifications/domain/` — every entity/enum listed above,
  the `NotificationsRepository` interface, and the `NotificationScheduler`/
  `PushNotificationHandler` service interfaces.
- `lib/features/notifications/data/datasources/
  notifications_remote_data_source.dart` — implements every call above
  exactly as documented. **Not yet integration-tested against a real
  server** — there is nothing to integration-test against.
- `lib/features/notifications/data/datasources/
  notifications_mock_data_source.dart` — a deterministic in-memory fixture
  (seven sample notifications, three sample reminders) with full read/
  write mutation support, used instead of the real API until it exists.
  **This is a UI-development aid only, not production content** — it also
  resets on app restart, since there is no local persistence layer for it.
- Presentation layer: Notification Center, Notification Details,
  Notification Preferences, Study Reminders, and the Study Reminder editor
  — all built against `NotificationsRepository`/`NotificationScheduler`
  only, never against a concrete datasource.

**Switching to the real backend once it ships:** set
`NOTIFICATIONS_API_AVAILABLE=true` in `mobile/env/{dev,staging,prod}.json`
(per environment, as each is ready) — see
`AppConfig.isNotificationsApiAvailable` in
`lib/core/config/app_config.dart`. No other mobile code needs to change.
If the actual response shape ends up differing from this document, only
`notifications_remote_data_source.dart` and the `data/models/*.dart` files
need updating — the domain layer, state management, and every screen are
unaffected.
