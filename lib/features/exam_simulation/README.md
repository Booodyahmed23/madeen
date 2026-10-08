# exam simulation

Timed exam simulation against `/exams/attempts/*`
(docs/MOBILE_API_CONTRACT.md §A4). `EXAM_SIMULATION_API_AVAILABLE` switches
between the real API and `ExamMockDataSource`, an in-memory stand-in that
returns the same JSON and applies the same rules (server clock, expiry,
reveal on submit).

Covers: Exam Setup (Program + Part, optionally Unit / Sub-unit, question
count → time limit) → Active Exam (countdown, flags, question navigator) →
Submission Review → Results (overall, per topic, wrong, unanswered) →
Post-Exam Review, plus reopening a running attempt (Home's "Continue your
exam" card). Must never share Study Session's routes or state.

## How it maps onto the API

- **Scope → topics:** Setup resolves the chosen node to its topic ids with
  the curriculum tree (`CurriculumTree.topicIdsUnder`, topics with no
  published questions left out) and sends `topicIds`. A scope with none
  isn't sent at all.
- **Duration:** `durationMinutes = clamp(ceil(seconds / 60), 5, 300)`.
- **Server-owned clock:** the countdown starts from `remainingSeconds` and
  is re-based on every response, and again when the app returns to the
  foreground (`ExamNotifier.resync`). At zero the app submits anyway; the
  server answers `EXPIRED`, shown as "Timed out".
- **Answers and flags** are saved on every tap (the latest pick counts).
  There is no "clear answer" — the API has none. Nothing is revealed until
  the attempt ends; then every question is, unanswered ones included.
- **Topic:** the payload carries each question's topic, but it is never
  shown while the attempt is in progress — only in Results and Review.
- **Submit** is idempotent: retrying a failed submission is safe.
- **Ids:** URLs use `questions[].questionId`. There is no order option: the
  server always shuffles.
- **Leaving** keeps the attempt (and its clock) running on the server; it
  can be reopened until it expires.
