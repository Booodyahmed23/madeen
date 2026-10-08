# subscription

Plans, access and coupons against the real API (docs/MOBILE_API_CONTRACT.md
§A6). No mock data source — these endpoints are available.

- `domain/` — `Plan`, `Entitlement`, `Subscription`, `CouponQuote` and the
  `SubscriptionRepository` interface.
- `data/` — `SubscriptionRemoteDataSource` (`/plans`, `/entitlements/me`,
  `/subscriptions/me`, `/coupons/validate`, `/coupons/redeem`) and the
  repository (errors → `AppFailure`; coupon error codes are translated by
  `core/error/failure_messages.dart`).
- `presentation/` — the Plans & access screen (reached from Profile and
  from every "no access" notice), the coupon sheet, `NoAccessNotice`, and
  the providers other features read:
  - `hasAccessProvider` — any active entitlement. Study Session and Exam
    setup show `NoAccessNotice` instead of their Start button without it.
    A `403` on start (`NoAccessFailure`) shows the same notice.
  - `defaultProgramIdProvider` — the first entitlement's program, used to
    preselect a program.

## Payment

Online payment isn't available yet; Paymob is planned. Until then paid
plans show their price and **Use a coupon** only. A coupon that makes the
plan free is redeemed in the app; one that only discounts it is shown but
can't be used (the API answers `COUPON_NOT_FREE`). Never fake a checkout.
