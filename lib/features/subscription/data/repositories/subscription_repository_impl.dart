import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_mapper.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/api_exception.dart';
import '../../domain/entities/coupon_quote.dart';
import '../../domain/entities/entitlement.dart';
import '../../domain/entities/plan.dart';
import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_data_source.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl(this._remote);

  final SubscriptionRemoteDataSource _remote;

  @override
  Future<Result<List<Plan>>> getPlans() => _guard(_remote.getPlans);

  @override
  Future<Result<List<Entitlement>>> getMyEntitlements() =>
      _guard(_remote.getMyEntitlements);

  @override
  Future<Result<List<Subscription>>> getMySubscriptions() =>
      _guard(_remote.getMySubscriptions);

  @override
  Future<Result<CouponQuote>> validateCoupon({
    required String code,
    required String planId,
  }) => _guard(() => _remote.validateCoupon(code: code, planId: planId));

  @override
  Future<Result<void>> redeemCoupon({
    required String code,
    required String planId,
  }) => _guard(() => _remote.redeemCoupon(code: code, planId: planId));

  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Result.success(await action());
    } on ApiException catch (error) {
      return Result.failure(mapApiExceptionToFailure(error));
    } catch (_) {
      // Unexpected response shape — never leak a TypeError to the UI.
      return const Result.failure(UnknownFailure());
    }
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>(
  (ref) => SubscriptionRepositoryImpl(
    ref.watch(subscriptionRemoteDataSourceProvider),
  ),
);
