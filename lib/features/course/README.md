# course — mock-backed, implemented (Phase 11)

Structured video courses: `Course → CourseSection → Lesson`, plus
`CourseEnrollment` for progress tracking only. Matches the backend module
of the same name (see `docs/ARCHITECTURE.md` §3/§13) — that backend
module does not exist yet, so this feature runs entirely on
`CourseMockDataSource`, gated by `AppConfig.isCourseApiAvailable` (default
`false`, and currently has no effect either way — see that flag's own doc
comment). See `COURSE_API_REQUIREMENTS.md` (mobile/ root) for the
proposed backend contract and exactly what's blocked on Entitlement/video
hosting decisions versus already fully built on mobile.

**Entitlement has zero implementation anywhere in this project.** Course
access is **not** gated by any subscription/plan check — every course is
simply browsable by every authenticated user, and `CourseEnrollment` is
never consulted to decide access, only to track progress (last position,
% complete). See `COURSE_API_REQUIREMENTS.md`'s "Entitlement / access
status" for the full rationale.

`Lesson.videoAssetId` is an opaque placeholder — **no real video exists**.
`VideoPlaceholder` renders an honest "not available yet" state instead of
a fake player; see `COURSE_API_REQUIREMENTS.md`'s "Video hosting status".

Talk to other features only through `core/` services, never by importing
another feature's internals.
