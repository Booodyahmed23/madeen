# study session

Question Bank / Study Session against `/study/sessions/*`
(docs/MOBILE_API_CONTRACT.md §A3). `STUDY_SESSION_API_AVAILABLE` switches
between the real API and `StudySessionMockDataSource`, an in-memory stand-in
that returns the same JSON and applies the same rules.

Covers: Study Session Setup → Active Study Session (count-up timer,
immediate or end-of-session feedback, flags, pause) → Submission Review →
Results → Question Review, plus reopening an unfinished session (Home's
"Continue studying" card). Does **not** cover Exam Simulation — a separate
feature that must not reuse this one's routes or state.

## How it maps onto the API

- The server owns the session: every answer, flag, pause/resume and the
  completion is a call that returns the whole Session object, which
  replaces the app's copy (`StudySessionActive.session`). Results and the
  review are derived from the completed session (`StudySession.toResult`,
  `toReview`) — the contract's formulas, not separate endpoints.
- **Answers:** "At the end" mode sends each pick as it's made. Immediate
  mode sends it on **Submit answer**, and the returned session reveals it.
  A revealed answer is locked on the client (the API would allow changing
  it). Skipping sends nothing.
- **Time:** the server *adds* `timeSpentSeconds`, so the notifier sends only
  the seconds spent on that question since its last answer call.
- **Ids:** URLs use `questions[].questionId` (the bank question), never the
  session-question `id`.
- **Order:** there is no order option — the server always shuffles.
- **Review:** a skipped question may or may not come back revealed
  (`correctChoiceId` is nullable); the review says so when it isn't.
- **Leaving** a session keeps it open on the server; `reopenSession`
  continues it (resuming it first if it was paused).
- **No access** (`403`) and **no questions** (`400`) on start show their own
  messages on Setup.
