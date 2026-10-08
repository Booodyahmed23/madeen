import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../../auth/presentation/providers/auth_notifier.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../domain/entities/entitlement.dart';
import '../../domain/entities/plan.dart';
import '../../domain/entities/subscription.dart';

/// The signed-in user's id — so access is re-fetched when the user changes,
/// not on every auth update (a token refresh, a profile edit).
final _userIdProvider = Provider<String?>((ref) {
  return ref.watch(
    authNotifierProvider.select(
      (state) => state is AuthAuthenticated ? state.user.id : null,
    ),
  );
});

final plansProvider = FutureProvider<List<Plan>>((ref) async {
  return _unwrap(await ref.watch(subscriptionRepositoryProvider).getPlans());
});

/// The student's active entitlements. Invalidate after anything that can
/// change access (redeeming a coupon).
final entitlementsProvider = FutureProvider<List<Entitlement>>((ref) async {
  if (ref.watch(_userIdProvider) == null) return const [];
  return _unwrap(
    await ref.watch(subscriptionRepositoryProvider).getMyEntitlements(),
  );
});

final subscriptionsProvider = FutureProvider<List<Subscription>>((ref) async {
  if (ref.watch(_userIdProvider) == null) return const [];
  return _unwrap(
    await ref.watch(subscriptionRepositoryProvider).getMySubscriptions(),
  );
});

/// Whether the student may start study sessions and exams (contract §A6):
/// any active entitlement. Loading/error while entitlements load.
final hasAccessProvider = FutureProvider<bool>((ref) async {
  final entitlements = await ref.watch(entitlementsProvider.future);
  return entitlements.isNotEmpty;
});

/// The program to preselect: the one whose access expires soonest (the
/// first entitlement), or `null` without access (contract §A2).
final defaultProgramIdProvider = FutureProvider<String?>((ref) async {
  final entitlements = await ref.watch(entitlementsProvider.future);
  return entitlements.isEmpty ? null : entitlements.first.programId;
});

T _unwrap<T>(Result<T> result) =>
    result.when(success: (value) => value, failure: (failure) => throw failure);
