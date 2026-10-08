import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../domain/entities/coupon_quote.dart';
import '../../domain/entities/entitlement.dart';
import '../../domain/entities/plan.dart';
import '../../domain/entities/subscription.dart';
import '../models/subscription_models.dart';

/// Plans, access and coupons (contract §A6). Always the real API — these
/// endpoints have no mock fallback.
class SubscriptionRemoteDataSource {
  SubscriptionRemoteDataSource(this._apiClient);

  final ApiClient _apiClient;

  Future<List<Plan>> getPlans() =>
      _apiClient.get('/plans', parse: (data) => _list(data, planFromJson));

  Future<List<Entitlement>> getMyEntitlements() => _apiClient.get(
    '/entitlements/me',
    parse: (data) => _list(data, entitlementFromJson),
  );

  Future<List<Subscription>> getMySubscriptions() => _apiClient.get(
    '/subscriptions/me',
    parse: (data) => _list(data, subscriptionFromJson),
  );

  Future<CouponQuote> validateCoupon({
    required String code,
    required String planId,
  }) => _apiClient.post(
    '/coupons/validate',
    data: {'code': code, 'planId': planId},
    parse: (data) => couponQuoteFromJson(data as Map<String, dynamic>),
  );

  Future<void> redeemCoupon({required String code, required String planId}) =>
      _apiClient.post(
        '/coupons/redeem',
        data: {'code': code, 'planId': planId},
        parse: (_) {},
      );

  static List<T> _list<T>(
    dynamic data,
    T Function(Map<String, dynamic> json) parse,
  ) => [for (final item in data as List) parse(item as Map<String, dynamic>)];
}

final subscriptionRemoteDataSourceProvider =
    Provider<SubscriptionRemoteDataSource>(
      (ref) => SubscriptionRemoteDataSource(ref.watch(apiClientProvider)),
    );
