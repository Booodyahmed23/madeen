# ai tutor — mock-backed, implemented (Phase 10)

Conversational study assistant. Matches the backend module of the same
name (see `docs/ARCHITECTURE.md` §3/§17.1) — that backend module does not
exist yet, so this feature runs entirely on `MockAiProvider`, gated by
`AppConfig.isAiTutorApiAvailable` (default `false`, and currently has no
effect either way — see that flag's own doc comment). See
`AI_TUTOR_API_REQUIREMENTS.md` (mobile/ root) for the proposed backend
contract and exactly what's blocked on a real LLM vendor/Entitlement
decision versus already fully built on mobile.

AI Tutor must never be reachable while an Exam Simulation attempt is in
progress (`ExamActive`/`ExamTimedOut`/`ExamSubmitting`) — enforced in
`core/router/app_router.dart`'s own `redirect`, not inside this feature.

Talk to other features only through `core/` services, never by importing
another feature's internals.
