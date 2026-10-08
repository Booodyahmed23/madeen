# exam simulation

Exam Simulation feature (Phase 5) — a timed, exam-mode experience,
architecturally **separate** from Study Session even though both are
question-answering flows. See `EXAM_SIMULATION_API_REQUIREMENTS.md` at the
`mobile/` root for the proposed backend contract; that backend module does
not exist yet, so this feature runs on local mock exam data by default (see
`AppConfig.isExamSimulationApiAvailable`).

## Why this is not "Study Session with a different timer"

The two features enforce genuinely different rules, at the type/state
level, not just visually:

| | Study Session | Exam Simulation |
|---|---|---|
| Timer | count-up, pausable | count-down, **no pause method exists on the notifier at all** |
| Topic context | shown (immediate parent) | **never present on `ExamQuestion` — there is no field for it** |
| Feedback during the activity | optional (immediate or at-end mode) | **never — no per-question network call exists to return it** |
| Question flagging | not applicable | a review/navigation aid, never affects scoring |
| Entities | `Question`, `AnswerChoice`, ... | `ExamQuestion`, `ExamAnswerChoice`, ... — its own types, not shared |

Do not "simplify" this feature by importing Study Session's entities,
state, or notifier, and do not add a pause button or topic display here to
"match" Study Session — those would undo the separation this feature
exists to have.

## Phase 15 — Simulation Mode completion

- **Setup**: Program + Part, optionally narrowed to a Unit and Sub-unit;
  question count (10/20/50/80) with the countdown derived from it
  (15/30/60/120 min — `examDurationFor`, placeholder presets); question
  order (original/random). The exam conditions are stated before starting.
- **During the exam**: the question navigator (bottom sheet) shows every
  question as current / answered / unanswered / flagged, plus a legend and
  the live countdown; the always-visible status line counts answered and
  flagged questions. Answers can be changed until submission.
- **Submission**: one shared confirmation (`confirmExamSubmission`) —
  "Submit Simulation?" with the unanswered count, or a plain confirmation
  when everything is answered — from the navigator or the Exam Review
  screen. Timeout still auto-submits.
- **Results**: overall performance (incl. average time per question), the
  per-topic breakdown, and the wrong/unanswered questions, each opening
  the post-exam review on that view. Topics come from the
  **post-submission** review only (`ExamReviewItem.topicId/topicName`) —
  `ExamQuestion` still has no topic field.
- **Analytics**: the recorded attempt carries one topic row per reviewed
  topic (`LocalAttemptRecord.topics`), so Performance (including its Exam
  Simulation filter) and AI Analysis see the simulation's strong/weak
  topics, pace and unanswered questions.

## Reused, on purpose

The Exam Setup screen reads Curriculum's `Program`/`Part` lists via
`curriculum_providers.dart` for its picker — that's read-only reuse of
canonical curriculum data (a real, justified reuse case), not a dependency
on Curriculum's internal screens or business logic, and nothing about
Curriculum changes because of it.

## Known limitations (see EXAM_SIMULATION_API_REQUIREMENTS.md for detail)

- The countdown timer is in-memory only — it does not survive the app
  process being killed, and is not wall-clock-exact across a long
  backgrounding. A server-authoritative deadline is required for a
  production-correct implementation; this client timer is a UX countdown,
  not the security boundary.
- `ExamRepository.getAttempt` exists and is implemented (mock + remote) but
  is not wired into any screen this phase — there's no local persistence of
  an in-progress attempt id to resume yet.

Talk to other features only through their public providers/repositories
(as above with Curriculum), never by importing another feature's
presentation internals.
