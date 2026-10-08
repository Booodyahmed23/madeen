import '../../domain/entities/coupon_quote.dart';
import '../../domain/entities/entitlement.dart';
import '../../domain/entities/plan.dart';
import '../../domain/entities/subscription.dart';

/// JSON → domain for the plans, entitlements, subscriptions and coupon
/// endpoints (contract §A6). The only place that knows these key names.

Plan planFromJson(Map<String, dynamic> json) {
  final program = json['program'] as Map<String, dynamic>?;
  return Plan(
    id: json['id'] as String,
    programId: json['programId'] as String,
    programName: program?['name'] as String? ?? '',
    name: json['name'] as String,
    description: json['description'] as String?,
    priceCents: (json['priceCents'] as num).toInt(),
    currency: json['currency'] as String,
    durationDays: (json['durationDays'] as num).toInt(),
  );
}

Entitlement entitlementFromJson(Map<String, dynamic> json) {
  final program = json['program'] as Map<String, dynamic>?;
  return Entitlement(
    id: json['id'] as String,
    programId: json['programId'] as String,
    programName: program?['name'] as String? ?? '',
    startsAt: DateTime.parse(json['startsAt'] as String),
    expiresAt: DateTime.parse(json['expiresAt'] as String),
  );
}

Subscription subscriptionFromJson(Map<String, dynamic> json) {
  final plan = json['plan'] as Map<String, dynamic>?;
  return Subscription(
    id: json['id'] as String,
    planId: json['planId'] as String,
    planName: plan?['name'] as String? ?? '',
    programId: plan?['programId'] as String? ?? '',
    status: json['status'] == 'ACTIVE'
        ? SubscriptionStatus.active
        : SubscriptionStatus.cancelled,
    source: switch (json['source']) {
      'PAYMENT' => SubscriptionSource.payment,
      'COUPON' => SubscriptionSource.coupon,
      _ => SubscriptionSource.admin,
    },
    startsAt: DateTime.parse(json['startsAt'] as String),
    endsAt: DateTime.parse(json['endsAt'] as String),
  );
}

CouponQuote couponQuoteFromJson(Map<String, dynamic> json) => CouponQuote(
  code: json['code'] as String,
  planId: json['planId'] as String,
  currency: json['currency'] as String,
  priceCents: (json['priceCents'] as num).toInt(),
  amountOffCents: (json['amountOffCents'] as num).toInt(),
  finalPriceCents: (json['finalPriceCents'] as num).toInt(),
);
