import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:mobile/features/subscription/domain/entities/coupon_quote.dart';
import 'package:mobile/features/subscription/domain/entities/entitlement.dart';
import 'package:mobile/features/subscription/domain/entities/plan.dart';
import 'package:mobile/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:mobile/features/subscription/presentation/providers/subscription_providers.dart';
import 'package:mobile/features/subscription/presentation/screens/plans_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

class MockSubscriptionRepository extends Mock
    implements SubscriptionRepository {}

const _plan = Plan(
  id: 'plan-1',
  programId: 'program-1',
  programName: 'CMA',
  name: 'Monthly',
  priceCents: 2900,
  currency: 'USD',
  durationDays: 30,
);

void main() {
  late MockSubscriptionRepository repository;
  late List<Entitlement> entitlements;

  setUp(() {
    repository = MockSubscriptionRepository();
    entitlements = [];
    when(() => repository.getPlans())
        .thenAnswer((_) async => const Result.success([_plan]));
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: appRetryPolicy,
        overrides: [
          subscriptionRepositoryProvider.overrideWithValue(repository),
          entitlementsProvider.overrideWith((ref) async => entitlements),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const PlansScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterCoupon(WidgetTester tester, String code) async {
    await tester.tap(find.text('Use a coupon'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), code);
    await tester.tap(find.text('Check coupon'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows plans with their price and no checkout', (tester) async {
    await pump(tester);

    expect(find.text('Monthly'), findsOneWidget);
    expect(find.text(r'$29.00'), findsOneWidget);
    expect(find.text('CMA · 30 days'), findsOneWidget);
    expect(
      find.text(
        "You don't have an active plan yet. Use a coupon on a plan below "
        'to get access.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Buy'), findsNothing);
  });

  testWidgets('a free coupon activates the plan', (tester) async {
    when(() => repository.validateCoupon(code: 'FREE100', planId: 'plan-1'))
        .thenAnswer(
          (_) async => const Result.success(
            CouponQuote(
              code: 'FREE100',
              planId: 'plan-1',
              currency: 'USD',
              priceCents: 2900,
              amountOffCents: 2900,
              finalPriceCents: 0,
            ),
          ),
        );
    when(() => repository.redeemCoupon(code: 'FREE100', planId: 'plan-1'))
        .thenAnswer((_) async => const Result.success(null));
    await pump(tester);

    await enterCoupon(tester, 'FREE100');
    expect(find.text('Free'), findsOneWidget);

    await tester.tap(find.text('Activate plan'));
    await tester.pumpAndSettle();

    verify(() => repository.redeemCoupon(code: 'FREE100', planId: 'plan-1'))
        .called(1);
    expect(find.text('Plan activated'), findsOneWidget);
  });

  testWidgets('a partial discount is shown but cannot be redeemed', (
    tester,
  ) async {
    when(() => repository.validateCoupon(code: 'HALF', planId: 'plan-1'))
        .thenAnswer(
          (_) async => const Result.success(
            CouponQuote(
              code: 'HALF',
              planId: 'plan-1',
              currency: 'USD',
              priceCents: 2900,
              amountOffCents: 1450,
              finalPriceCents: 1450,
            ),
          ),
        );
    await pump(tester);

    await enterCoupon(tester, 'HALF');

    expect(find.text(r'$14.50'), findsOneWidget);
    expect(find.text('Activate plan'), findsNothing);
    verifyNever(
      () => repository.redeemCoupon(
        code: any(named: 'code'),
        planId: any(named: 'planId'),
      ),
    );
  });

  testWidgets('an invalid coupon shows the translated error', (tester) async {
    when(() => repository.validateCoupon(code: 'NOPE', planId: 'plan-1'))
        .thenAnswer(
          (_) async => const Result.failure(
            ValidationFailure('Invalid coupon code', code: 'COUPON_INVALID'),
          ),
        );
    await pump(tester);

    await enterCoupon(tester, 'NOPE');

    expect(find.text("This coupon code isn't valid."), findsOneWidget);
  });

  testWidgets('lists current access', (tester) async {
    entitlements = [
      Entitlement(
        id: 'e1',
        programId: 'program-1',
        programName: 'CMA',
        startsAt: DateTime.utc(2026, 1, 1),
        expiresAt: DateTime.utc(2026, 12, 26, 12),
      ),
    ];
    await pump(tester);

    expect(find.text('Access until Dec 26, 2026'), findsOneWidget);
    expect(find.text('You have access'), findsOneWidget);
  });
}
