# AI Tutor API — required backend contract (not yet implemented)

**Status as of Phase 10 (mobile): these endpoints do not exist on the
backend, and no LLM vendor has been chosen.** Verified by inspection —
`backend/src/modules/` currently contains only `identity` and
`notification`; there is no `AITutor` module (see `docs/ARCHITECTURE.md`
§3/§17.1 for where it's planned). This document is the mobile app's
proposed contract, written so whoever implements the backend module can do
so without reading Flutter code. It mirrors the style of
`AI_ANALYSIS_API_REQUIREMENTS.md` and `docs/API_AUTH.md`.

Until this exists, the mobile app runs entirely on `MockAiProvider` — a
deterministic, keyword-matched set of canned study-assistance replies (see
"Current mobile-side status" below). **Do not treat this document as an
existing API** — no backend code has been written to match it, and the
exact endpoint path/shape below is a proposal, not a confirmed contract.

**PROPOSED / BACKEND DEPENDENCY — every endpoint in this document.**

## Why this is two different problems, not one

Per `docs/ARCHITECTURE.md` §17.1, AI Tutor is explicitly a *different*
design from AI Analysis (§17.2, already shipped — see
`AI_ANALYSIS_API_REQUIREMENTS.md`): AI Analysis is a deterministic
aggregation pipeline the LLM only phrases; AI Tutor is a genuine
conversational feature where the LLM *is* the source of the reply. That
means this contract needs three things AI Analysis's never did, **none of
which this document resolves**:

1. **An LLM vendor.** §30 (Open Decisions) item 11 is still open. `AiProvider`
   (see `data/datasources/ai_provider.dart`) exists specifically so this
   choice never touches more than one implementation class on mobile —
   but the choice itself is a product/business decision this document
   does not make.
2. **Entitlement / usage quotas.** §15.6 extends Entitlement with a quota
   concept ("AI Tutor: 50 messages/month") specifically for this feature,
   because unlike most of the app, every message sent here has a real
   per-call LLM cost. **Entitlement has zero implementation anywhere in
   this project (mobile or backend) as of this phase.** Mobile does **not**
   invent a quota UI, a message counter, or a fake "upgrade to continue"
   prompt — there is nothing real to gate against yet, and pretending
   otherwise would misrepresent a capability that doesn't exist.
3. **Exam integrity.** §17.1: AI Tutor is "explicitly blocked during any
   `IN_PROGRESS` `SimulationAttempt`." Mobile already enforces this
   independently of the backend (see "Exam Simulation restriction" below)
   — a real backend should enforce it too (never trust client-side
   blocking as the actual security boundary, per §21.1), but that's a
   backend-side requirement this document flags, not implements.

## Endpoints

All under the existing `/api/v1` prefix, alongside `/auth/*`,
`/performance/*`, and the other proposed contracts in this directory.

**Auth:** every endpoint below requires the same authenticated-user access
as the rest of the app (bearer access token, per `docs/API_AUTH.md`). No
`userId` parameter anywhere — every response is implicitly scoped to the
authenticated caller.

**Locale:** mirrors `AI_ANALYSIS_API_REQUIREMENTS.md`'s own convention —
the client sends the student's current effective UI language, the backend
(or the LLM prompt template) is responsible for generating that
language's copy. Not a bilingual `{en, ar}` payload.

### `POST /api/v1/ai-tutor/messages`

**Request body:**

```json
{
  "conversationId": "conv-local-1",
  "history": [
    { "role": "USER", "content": "What is variance analysis?" },
    { "role": "ASSISTANT", "content": "Variance analysis compares..." }
  ],
  "content": "Can you give an example?",
  "locale": "en"
}
```

`conversationId` — client-generated (see `TutorConversation.id`); a real
backend may choose to persist conversations keyed by this, or treat it as
opaque. `history` — every prior message in the conversation, oldest
first; this client never asks the backend to remember history itself
(no "Phase 10" persistence exists — see "Current mobile-side status").

**Response `200`:**

```json
{
  "id": "tutor-msg-server-assigned-id",
  "role": "ASSISTANT",
  "content": "A good example is...",
  "timestamp": "2026-09-16T09:05:00.000Z"
}
```

`role` is always `"ASSISTANT"` for this endpoint's response. `id`/
`timestamp` are server-assigned — mobile's own `MockAiProvider` assigns a
local placeholder of each today, which a real implementation should
replace outright, not merge with.

**Errors:** the standard envelope from `docs/API_AUTH.md`
(`{statusCode, message, error, path, timestamp, requestId}`). `401` per
normal auth rules. `403` is the natural status for "blocked — this
account's Entitlement doesn't currently grant AI Tutor access" or "blocked
— quota exhausted for this period," **once Entitlement/quotas exist** — no
such response is defined yet because nothing produces it yet. `429` if a
per-user rate limit is added independently of quota (mirrors
`AI_ANALYSIS_API_REQUIREMENTS.md`'s own note on this). `500` on server
error, including an underlying LLM vendor failure — the response shape for
"the LLM call itself failed" vs. "our server errored" is an implementation
detail a real backend can choose; the client only distinguishes failures
by HTTP status via the existing `AppFailure` mapping, same as every other
feature.

## Shared field notes

- `role` — `USER` | `ASSISTANT`, matching `TutorMessageRole.toWire()`.
- There is deliberately **no `conversations` list/history endpoint** in
  this proposal — Phase 10's mobile implementation never persists a
  conversation past the screen closing (see below), so there is nothing
  to list yet. A real backend that *does* persist conversations would add
  `GET /api/v1/ai-tutor/conversations` and
  `GET /api/v1/ai-tutor/conversations/:id` as a straightforward additive
  change — domain layer, state management, and every screen are
  unaffected either way, since [TutorRepository] already takes the full
  history as an explicit parameter rather than assuming the backend holds
  it.

## Local/conversation persistence status

**No conversation is ever saved past the screen closing.** Starting a new
conversation, or navigating away and back, loses whatever was there — this
is a deliberate Phase 10 scope cut (`TutorConversation` lives only in
`TutorConversationNotifier`'s in-memory state), not an oversight. Adding
persistence (local-only, or via the backend once it exists) is future
work.

## LLM provider status

**No LLM vendor has been chosen.** `data/datasources/ai_provider.dart`'s
`AiProvider` interface exists so that choice is a single new
implementation class (`RealAiProvider`, calling the endpoint above) with
no change to `TutorRepository`, state management, or any screen — but
this document does not choose a vendor, and no mobile code assumes one.

## Entitlement / quota status

**Entitlement has no implementation anywhere in this project.** Per
§15.6, this feature is the one §17.1 specifically calls out as needing a
usage quota (not just a yes/no gate), because every real message has an
LLM cost. Mobile does not display any quota UI, remaining-message count,
or paywall prompt — there is nothing real to show. This is a hard blocker
on the *real* feature being cost-safe to ship; it is **not** a blocker on
the mock, which has no real per-call cost.

## Exam Simulation restriction

Enforced today, independent of any backend: `core/router/app_router.dart`'s
`redirect` checks `examNotifierProvider` and bounces any attempt to reach
`/ai-tutor` back to `/exam-simulation/active` while an attempt is
`ExamActive`, `ExamTimedOut`, or `ExamSubmitting` — covering Home's own
entry card (shown visibly disabled during this window) and any other path
into the route (a future deep link, programmatic navigation, ...). A real
backend should enforce the same rule server-side once it exists (§21.1 —
never trust a client-side-only boundary for anything that matters), but
that is a backend-side requirement, not something this mobile
implementation can satisfy on the backend's behalf.

## Current mobile-side status

The mobile app already has the full client-side abstraction ready for
this contract:

- `lib/features/ai_tutor/domain/` — `TutorMessage`, `TutorMessageRole`,
  `TutorConversation` entities and the `TutorRepository` interface.
- `lib/features/ai_tutor/data/datasources/ai_provider.dart` — the
  `AiProvider` interface a future `RealAiProvider` (calling the endpoint
  above) would implement.
- `lib/features/ai_tutor/data/datasources/mock_ai_provider.dart` — a
  deterministic, keyword-matched generator used instead of the real API
  until it exists. **This generated content is a UI-development aid
  only — it is not, and must never be mistaken for, a real AI response.**
- Presentation layer: `AiTutorScreen` with a welcome/suggested-prompts
  empty state, message bubbles, a typing indicator, inline error
  handling, and a new-conversation action — all built against
  `TutorRepository` only, never against `MockAiProvider` directly.

**Switching to the real backend once it ships (and a vendor is chosen):**
set `AI_TUTOR_API_AVAILABLE=true` in `mobile/env/{dev,staging,prod}.json`.
**This currently has no effect** — see `AppConfig.isAiTutorApiAvailable`'s
own doc comment — until a `RealAiProvider` implementation is written and
wired into `aiProviderProvider` (`data/datasources/mock_ai_provider.dart`)
to be selected when the flag is true. No other mobile code needs to
change at that point — the domain layer, state management, and every
screen are unaffected.
