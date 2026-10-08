import '../../../../core/error/result.dart';
import '../entities/coupon_quote.dart';
import '../entities/entitlement.dart';
import '../entities/plan.dart';
import '../entities/subscription.dart';

abstract class SubscriptionRepository {
  /// Active plans, cheapest first.
  Future<Result<List<Plan>>> getPlans();

  /// The student's active entitlements, soonest expiry first. Non-empty
  /// means they can start study sessions and exams.
  Future<Result<List<Entitlement>>> getMyEntitlements();

  Future<Result<List<Subscription>>> getMySubscriptions();

  Future<Result<CouponQuote>> validateCoupon({
    required String code,
    required String planId,
  });

  /// Redeems a coupon that makes the plan free, creating a subscription.
  Future<Result<void>> redeemCoupon({
    required String code,
    required String planId,
  });
}
