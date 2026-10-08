import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mobile/features/subscription/domain/entities/entitlement.dart';
import 'package:mobile/features/subscription/presentation/providers/subscription_providers.dart';

/// An active entitlement to the sample CMA program.
final testEntitlement = Entitlement(
  id: 'entitlement-1',
  programId: 'program-cma',
  programName: 'CMA',
  startsAt: DateTime.utc(2026, 1, 1),
  expiresAt: DateTime.utc(2027, 1, 1),
);

/// Gives a test's ProviderScope a student with (or, with [hasAccess] false,
/// without) an active plan — so no test reaches the network for
/// `/entitlements/me`.
List<Override> accessOverrides({bool hasAccess = true}) => [
  entitlementsProvider.overrideWith(
    (ref) async => hasAccess ? [testEntitlement] : const <Entitlement>[],
  ),
];
