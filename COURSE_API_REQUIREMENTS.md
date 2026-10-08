# Course API — required backend contract (not yet implemented)

**Status as of Phase 11 (mobile): these endpoints do not exist on the
backend.** Verified by inspection — `backend/src/modules/` currently
contains only `identity` and `notification`; there is no `Course` module
(see `docs/ARCHITECTURE.md` §3/§13 for where it's planned). This document
is the mobile app's proposed contract, written so whoever implements the
backend module can do so without reading Flutter code. It mirrors the
style of `AI_TUTOR_API_REQUIREMENTS.md` and `docs/API_AUTH.md`.

Until this exists, the mobile app runs entirely on `CourseMockDataSource`
— hand-written, bilingual (English/Arabic) sample course content (see
"Current mobile-side status" below). **Do not treat this document as an
existing API** — no backend code has been written to match it, and the
exact endpoint path/shape below is a proposal, not a confirmed contract.

**PROPOSED / BACKEND DEPENDENCY — every endpoint in this document.**

## Endpoints

All under the existing `/api/v1` prefix, alongside `/auth/*`,
`/performance/*`, and the other proposed contracts in this directory.

**Auth:** every endpoint below requires the same authenticated-user access
as the rest of the app (bearer access token, per `docs/API_AUTH.md`). No
`userId` parameter anywhere — every response is implicitly scoped to the
authenticated caller.

**Locale:** mirrors `AI_ANALYSIS_API_REQUIREMENTS.md`'s own convention for
*generated* copy, but Course content is **authored**, not generated — per
`docs/ARCHITECTURE.md` §19's `_i18n` convention, a real backend would
store `title`/`description` per-field as `{ en, ar }` (or equivalent
translation rows) and the client sends its current effective UI language
as a query parameter so the server returns the matching copy, the same
shape `CourseMockDataSource` already picks between.

### `GET /api/v1/courses?locale=en`

**Response `200`:**

```json
[
  {
    "id": "course-cma-part-1",
    "title": "CMA Part 1 Video Course",
    "description": "A structured video walkthrough of...",
    "thumbnailAssetId": null,
    "sections": [
      {
        "id": "section-budgeting",
        "courseId": "course-cma-part-1",
        "title": "Budgeting and Forecasting",
        "order": 0,
        "lessons": [
          {
            "id": "lesson-intro-budgeting",
            "sectionId": "section-budgeting",
            "title": "Introduction to Budgeting",
            "description": "Why budgets exist...",
            "durationSeconds": 540,
            "order": 0,
            "videoAssetId": "video-placeholder-1"
          }
        ]
      }
    ]
  }
]
```

A course's full tree (every section and lesson) is returned in one
response — unlike Curriculum's Program→Part→Unit→SubUnit→Topic tree,
which is fetched level-by-level, a course's tree is shallow and small
enough that paginating it would only add round trips (see
`Course`'s own doc comment). **No access-control filtering happens
here** — see "Entitlement / access status" below; every course a real
backend returns from this endpoint is one every authenticated caller can
see and browse.

### `GET /api/v1/courses/:courseId/enrollment`

Returns (lazily creating on first call, same as `CourseMockDataSource`)
this caller's own progress through one course:

```json
{
  "courseId": "course-cma-part-1",
  "completedLessonIds": ["lesson-intro-budgeting"],
  "lastAccessedLessonId": "lesson-intro-budgeting"
}
```

### `PUT /api/v1/courses/:courseId/enrollment/lessons/:lessonId/completed`

**Request body:** `{ "completed": true }`. **Response `200`:** the
updated enrollment, same shape as the `GET` above.

### `PUT /api/v1/courses/:courseId/enrollment/last-accessed-lesson`

**Request body:** `{ "lessonId": "lesson-flexible-budgets" }`. **Response
`200`:** the updated enrollment.

**Errors:** the standard envelope from `docs/API_AUTH.md`
(`{statusCode, message, error, path, timestamp, requestId}`). `401` per
normal auth rules. `404` for an unknown `courseId`/`lessonId`. `500` on
server error. There is deliberately no `403` "not entitled" response
defined here — see "Entitlement / access status" below for why.

## Entitlement / access status

**Entitlement has zero implementation anywhere in this project (mobile or
backend) as of this phase.** Per `docs/ARCHITECTURE.md` §13.3/§15, a real
backend would eventually gate which courses a given student can open
behind their subscription/purchase — but that system does not exist yet,
in any form, on either side. Mobile does **not**:

- show a fake "Premium unlocked" / "locked" badge on any course,
- hardcode a plan check (e.g. "only CMA Part 1 is free"),
- implement any subscription or payment logic, or
- pretend `CourseEnrollment` is an access-control record — it is **only**
  ever used for progress tracking (last position, % complete), per that
  entity's own doc comment.

Every course the mock returns is simply browsable by every authenticated
user. This is a hard blocker on this feature's *real-money* readiness; it
is **not** a blocker on the mock, which has nothing to gate.

## Video hosting status

**No video vendor has been chosen, and no real video exists for any
lesson.** `Lesson.videoAssetId` (e.g. `"video-placeholder-1"`) is an
opaque reference with nothing real behind it — never a YouTube/Vimeo/Mux
URL, player id, or embed code. The Lesson Details screen renders an
honest placeholder (`VideoPlaceholder`) instead of a fake "playing" state.
Once a vendor is chosen, this field's *meaning* (not its type) would
become "this vendor's asset id," and only `VideoPlaceholder` and whatever
player widget replaces it would need to change — the domain entity,
repository, and every other screen are unaffected.

## Current mobile-side status

The mobile app already has the full client-side abstraction ready for
this contract:

- `lib/features/course/domain/` — `Course`, `CourseSection`, `Lesson`,
  `CourseEnrollment` entities and the `CourseRepository` interface.
- `lib/features/course/data/datasources/course_data_source.dart` — the
  `CourseDataSource` interface a future `CourseRemoteDataSource` (calling
  the endpoints above) would implement.
- `lib/features/course/data/datasources/course_mock_data_source.dart` — a
  bilingual, hand-written set of sample courses used instead of the real
  API until it exists. **This mock content is a UI-development aid
  only — it is not, and must never be mistaken for, real course content,
  real video, or a real enrollment record.**
- Presentation layer: `CoursesScreen` (list), `CourseDetailsScreen`
  (sections/lessons + progress), and `LessonDetailsScreen` (video
  placeholder, description, mark-as-completed, previous/next
  navigation) — all built against `CourseRepository` only, never against
  `CourseMockDataSource` directly.

**Switching to the real backend once it ships:** set
`COURSE_API_AVAILABLE=true` in `mobile/env/{dev,staging,prod}.json`.
**This currently has no effect** — see `AppConfig.isCourseApiAvailable`'s
own doc comment — until a `CourseRemoteDataSource` implementation is
written and wired into `courseDataSourceProvider`
(`data/datasources/course_data_source.dart`) to be selected when the flag
is true. No other mobile code needs to change at that point — the domain
layer, state management, and every screen are unaffected.
