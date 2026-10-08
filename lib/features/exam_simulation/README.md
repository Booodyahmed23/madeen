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
exam" card).

## Why this is not "Study Session with a different timer"

The two features enforce genuinely different rules, at the type/state
level, not just visually:

| | Study Session | Exam Simulation |
|---|---|---|
| Timer | count-up, pausable | count-down from the server's clock, **no pause method exists on the notifier at all** |
| Topic context | shown (immediate parent) | in the payload, but **never on `ExamQuestion`** — only in Results/Review |
| Feedback during the activity | optional (immediate or at-end mode) | **never — the API reveals nothing until the attempt ends** |
| Question flagging | a server-side marker | a review/navigation aid, never affects scoring |
| Entities | `StudySession`, `Question`, ... | `ExamAttempt`, `ExamQuestion`, ... — its own types, not shared |

Do not "simplify" this feature by importing Study Session's entities,
state, or notifier, and do not add a pause button or topic display here to
"match" Study Session — those would undo the separation this feature
exists to have.

## Screens

- **Setup**: Program (preselected from the student's access) + Part,
  optionally narrowed to a Unit and Sub-unit; question count (10/20/50/80)
  with the time limit derived from it (15/30/60/120 min — `examDurationFor`,
  placeholder presets). The exam conditions are stated before starting.
- **During the exam**: the question navigator (bottom sheet) shows every
  question as current / answered / unanswered / flagged, plus a legend and
  the live countdown; the always-visible status line counts answered and
  flagged questions. Answers can be changed until submission.
- **Submission**: one shared confirmation (`confirmExamSubmission`) —
  "Submit Simulation?" with the unanswered count, or a plain confirmation
  when everything is answered — from the navigator or the Exam Review
  screen. Timeout still submits.
- **Results**: overall performance (incl. average time per question), the
  per-topic breakdown, and the wrong/unanswered questions, each opening
  the post-exam review on that view.
- **Analytics**: the recorded attempt carries one topic row per reviewed
  topic (`LocalAttemptRecord.topics`), so Performance and AI Analysis see
  the simulation's strong/weak topics, pace and unanswered questions.

## Reused, on purpose

Exam Setup reads Curriculum's programs and program tree via
`curriculum_providers.dart` — read-only reuse of canonical curriculum data,
not a dependency on Curriculum's screens or business logic. Talk to other
features only through their public providers/repositories, never by
importing another feature's presentation internals.

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
