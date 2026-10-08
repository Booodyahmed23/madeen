/// What a coupon does to a plan's price — `POST /coupons/validate`.
class CouponQuote {
  const CouponQuote({
    required this.code,
    required this.planId,
    required this.currency,
    required this.priceCents,
    required this.amountOffCents,
    required this.finalPriceCents,
  });

  final String code;
  final String planId;
  final String currency;
  final int priceCents;
  final int amountOffCents;
  final int finalPriceCents;

  /// Only a coupon that brings the price to zero can be redeemed in the app
  /// (there is no online payment yet).
  bool get isRedeemable => finalPriceCents == 0;
}
