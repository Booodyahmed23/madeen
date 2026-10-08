# study session

Question Bank / Study Session feature (Phase 4). Matches the backend
module of the same name (see docs/ARCHITECTURE.md §3) — that backend
module does not exist yet, so this feature runs on local sample data by
default; see `STUDY_SESSION_API_REQUIREMENTS.md` at the `mobile/` root for
the proposed contract and the mock/real data-source switch
(`AppConfig.isStudySessionApiAvailable`).

Covers: Study Session Setup → Active Study Session (count-up timer,
immediate or end-of-session feedback) → Submission Review → Results →
Question Review. Does **not** cover Exam Simulation (countdown timer,
proctoring, analytics) — that is a separate, later feature and must not
reuse this one's routes or state.

Talk to other features only through `core/` services, never by importing
another feature's internals.
