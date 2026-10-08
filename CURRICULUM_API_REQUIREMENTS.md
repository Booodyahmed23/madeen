# Curriculum API — required backend contract (not yet implemented)

**Status as of Phase 3 (mobile): these endpoints do not exist on the
backend.** Verified by inspection — `backend/src/modules/` currently
contains only `identity` and `notification`. This document is the mobile
app's proposed contract, written so whoever implements the backend
Curriculum module can do so without needing to read Flutter code, and so
the two sides agree on shapes ahead of time. It intentionally mirrors the
style of `docs/API_AUTH.md`.

Until this exists, the mobile app runs entirely on local sample data — see
"Current mobile-side status" at the bottom.

## Why these shapes

The hierarchy is fixed by `docs/ARCHITECTURE.md`: Program → Part → Unit →
Sub-unit → Topic. Each level's endpoint takes only its immediate parent's
id — the mobile client never needs to send or receive the full ancestor
chain, since each screen only fetches its own direct children.

## Endpoints

All under the existing `/api/v1` prefix, alongside `/auth/*` and
`/users/*`.

### `GET /api/v1/programs`

- **Auth:** matches whatever the rest of the app requires for browsing
  content (this document assumes "authenticated user," consistent with the
  mobile app gating `/curriculum` behind login — see ARCHITECTURE.md §7 for
  the project's general stance that content access should be authenticated
  even before any paid-entitlement gate exists).
- **Response `200`:**

```json
[
  {
    "id": "prog-cma",
    "name": "CMA",
    "code": "CMA",
    "description": "Certified Management Accountant",
    "imageUrl": null,
    "order": 0,
    "isActive": true
  }
]
```

| Field | Type | Required | Notes |
|---|---|---|---|
| `id` | `string` | yes | |
| `name` | `string` | yes | |
| `code` | `string` | yes | e.g. `"CMA"`, `"FMAA"` |
| `description` | `string \| null` | no | |
| `imageUrl` | `string \| null` | no | |
| `order` | `number` | no (default `0`) | display sort order |
| `isActive` | `boolean \| null` | no | omit entirely if the backend has no publish/active concept yet — the client treats missing as "visible" |

### `GET /api/v1/programs/{programId}/parts`

Same shape as above, per item:

```json
[{ "id": "cma-part-1", "programId": "prog-cma", "name": "Part 1", "description": null, "order": 0 }]
```

`programId` in the response body is expected on every item (not just
implied by the URL) — the client stores it on the domain entity.

### `GET /api/v1/parts/{partId}/units`

```json
[{ "id": "unit-financial-planning", "partId": "cma-part-1", "name": "Financial Planning", "description": null, "order": 0 }]
```

### `GET /api/v1/units/{unitId}/sub-units`

```json
[{ "id": "subunit-budgeting", "unitId": "unit-financial-planning", "name": "Budgeting", "description": null, "order": 0 }]
```

### `GET /api/v1/sub-units/{subUnitId}/topics`

```json
[{ "id": "topic-flexible-budget", "subUnitId": "subunit-budgeting", "name": "Flexible Budget", "description": null, "order": 0 }]
```

## Common behavior expected of every endpoint above

- **Empty result:** `200` with `[]` — not a `404`. A program/part/unit/etc.
  with no children yet is a normal, valid state (the mobile empty-state UI
  depends on this).
- **Unknown parent id:** either `200` with `[]`, or `404` with the standard
  error envelope (see `docs/API_AUTH.md`'s "Common response shapes" — the
  same `{statusCode, message, error, path, timestamp, requestId}` shape).
  The mobile client treats both the same way (empty list), so either is
  fine — pick whichever is more consistent with how the rest of the API
  already handles a not-found parent.
- **Ordering:** the client does **not** re-sort by `order` itself — return
  items already sorted server-side.
- **Errors:** the standard envelope from `docs/API_AUTH.md` (`401`/`403` per
  the normal auth rules, `500` on server error). No curriculum-specific
  error shape is needed.

## Current mobile-side status

The mobile app already has the full client-side abstraction ready for this
contract:

- `lib/features/curriculum/domain/` — `Program`/`Part`/`Unit`/`SubUnit`/`Topic`
  entities and the `CurriculumRepository` interface.
- `lib/features/curriculum/data/datasources/curriculum_remote_data_source.dart`
  — implements the calls above exactly as documented. **Not yet exercised
  against a real server** — there is nothing to integration-test against.
- `lib/features/curriculum/data/datasources/curriculum_mock_data_source.dart`
  — local sample data (CMA/FMAA, a handful of parts/units/sub-units/topics),
  used instead of the real API until it exists.

**Switching to the real backend once it ships:** set
`CURRICULUM_API_AVAILABLE=true` in `mobile/env/{dev,staging,prod}.json` (per
environment, as each is ready) — see `AppConfig.isCurriculumApiAvailable` in
`lib/core/config/app_config.dart`. No other mobile code needs to change. If
the actual response shape ends up differing from this document, only
`curriculum_remote_data_source.dart` and the `data/models/*.dart` files need
updating — the domain layer and every screen are unaffected.
