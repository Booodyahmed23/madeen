import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/subscription/data/models/subscription_models.dart';
import 'package:mobile/features/subscription/domain/entities/subscription.dart';

void main() {
  test('parses a plan from GET /plans', () {
    final plan = planFromJson({
      'id': 'plan-1',
      'programId': 'program-1',
      'name': 'Quarterly',
      'description': 'Best for a single exam window.',
      'priceCents': 6900,
      'currency': 'USD',
      'durationDays': 90,
      'isActive': true,
      'createdAt': '2026-09-27T08:18:13.740Z',
      'updatedAt': '2026-09-27T08:18:13.740Z',
      'program': {'id': 'program-1', 'name': 'CMA (Demo)'},
    });

    expect(plan.programName, 'CMA (Demo)');
    expect(plan.priceCents, 6900);
    expect(plan.durationDays, 90);
    expect(plan.isFree, isFalse);
  });

  test('parses an entitlement from GET /entitlements/me', () {
    final entitlement = entitlementFromJson({
      'id': 'e1',
      'userId': 'u1',
      'programId': 'program-1',
      'subscriptionId': 's1',
      'startsAt': '2026-09-27T08:18:13.849Z',
      'expiresAt': '2026-12-26T08:18:13.849Z',
      'revokedAt': null,
      'createdAt': '2026-09-27T08:18:13.851Z',
      'program': {'id': 'program-1', 'name': 'CMA (Demo)'},
    });

    expect(entitlement.programName, 'CMA (Demo)');
    expect(entitlement.expiresAt, DateTime.utc(2026, 12, 26, 8, 18, 13, 849));
  });

  test('parses a subscription from GET /subscriptions/me', () {
    final subscription = subscriptionFromJson({
      'id': 's1',
      'userId': 'u1',
      'planId': 'plan-1',
      'status': 'ACTIVE',
      'source': 'COUPON',
      'startsAt': '2026-09-27T08:18:13.849Z',
      'endsAt': '2026-12-26T08:18:13.849Z',
      'cancelledAt': null,
      'plan': {'id': 'plan-1', 'name': 'Quarterly', 'programId': 'program-1'},
      'entitlement': null,
    });

    expect(subscription.status, SubscriptionStatus.active);
    expect(subscription.source, SubscriptionSource.coupon);
    expect(subscription.planName, 'Quarterly');
  });

  test('a coupon is redeemable only when it makes the plan free', () {
    final free = couponQuoteFromJson({
      'code': 'FREE100',
      'planId': 'plan-1',
      'currency': 'USD',
      'priceCents': 2900,
      'amountOffCents': 2900,
      'finalPriceCents': 0,
    });
    final partial = couponQuoteFromJson({
      'code': 'HALF',
      'planId': 'plan-1',
      'currency': 'USD',
      'priceCents': 2900,
      'amountOffCents': 1450,
      'finalPriceCents': 1450,
    });

    expect(free.isRedeemable, isTrue);
    expect(partial.isRedeemable, isFalse);
  });
}
