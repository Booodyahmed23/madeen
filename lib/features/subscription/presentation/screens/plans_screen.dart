import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/entitlement.dart';
import '../../domain/entities/plan.dart';
import '../providers/subscription_providers.dart';
import '../widgets/coupon_sheet.dart';
import '../widgets/money_format.dart';

/// The student's current access (`GET /entitlements/me`) and the plans they
/// can get (`GET /plans`). There is no online payment yet, so a plan is
/// activated with a coupon only — never a fake checkout (contract §A6).
class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final entitlements = ref.watch(entitlementsProvider);
    final plans = ref.watch(plansProvider);

    Future<void> reload() async {
      ref
        ..invalidate(entitlementsProvider)
        ..invalidate(plansProvider);
      await Future.wait([
        ref.read(entitlementsProvider.future),
        ref.read(plansProvider.future),
      ]).catchError((Object _) => const <List<Object>>[]);
    }

    final failure = switch ((entitlements.error, plans.error)) {
      (final AppFailure f, _) || (_, final AppFailure f) => f,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l10n.plansTitle)),
      body: switch ((entitlements, plans)) {
        _ when failure != null => MadeenErrorState(
          message: localizedFailureMessage(l10n, failure),
          retryLabel: l10n.authRetry,
          onRetry: reload,
        ),
        (AsyncData(value: final owned), AsyncData(value: final available)) =>
          RefreshIndicator(
            onRefresh: reload,
            child: _PlansBody(entitlements: owned, plans: available),
          ),
        _ when entitlements.hasError || plans.hasError => MadeenErrorState(
          message: l10n.errorUnknown,
          retryLabel: l10n.authRetry,
          onRetry: reload,
        ),
        _ => const Center(child: MadeenLoadingState()),
      },
    );
  }
}

class _PlansBody extends StatelessWidget {
  const _PlansBody({required this.entitlements, required this.plans});

  final List<Entitlement> entitlements;
  final List<Plan> plans;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final ownedPrograms = {for (final e in entitlements) e.programId};

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        MadeenSpace.lg,
        MadeenSpace.pageMargin,
        MadeenSpace.xl,
      ),
      children: [
        MadeenSectionHeader(title: l10n.plansYourAccessSection),
        const SizedBox(height: MadeenSpace.sm),
        if (entitlements.isEmpty)
          Text(
            l10n.plansNoAccess,
            style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
          )
        else
          for (final entitlement in entitlements)
            Padding(
              padding: const EdgeInsets.only(bottom: MadeenSpace.xs),
              child: _AccessCard(entitlement: entitlement),
            ),
        const SizedBox(height: MadeenSpace.xl),
        MadeenSectionHeader(title: l10n.plansAvailableSection),
        const SizedBox(height: MadeenSpace.xs),
        Text(
          l10n.plansPaymentComingSoon,
          style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
        ),
        const SizedBox(height: MadeenSpace.sm),
        if (plans.isEmpty)
          Text(
            l10n.plansNone,
            style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
          )
        else
          for (final plan in plans)
            Padding(
              padding: const EdgeInsets.only(bottom: MadeenSpace.sm),
              child: _PlanCard(
                plan: plan,
                hasAccess: ownedPrograms.contains(plan.programId),
              ),
            ),
      ],
    );
  }
}

class _AccessCard extends StatelessWidget {
  const _AccessCard({required this.entitlement});

  final Entitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final locale = Localizations.localeOf(context).toString();
    final until = DateFormat.yMMMd(locale)
        .format(entitlement.expiresAt.toLocal());

    return MadeenCard(
      child: Row(
        children: [
          Icon(Icons.verified_outlined, color: t.success),
          const SizedBox(width: MadeenSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entitlement.programName,
                  style: MadeenType.headlineSm.copyWith(color: t.ink),
                ),
                const SizedBox(height: MadeenSpace.xxs),
                Text(
                  l10n.plansAccessUntil(until),
                  style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.hasAccess});

  final Plan plan;
  final bool hasAccess;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final description = plan.description;

    return MadeenCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: MadeenType.headlineSm.copyWith(color: t.ink),
                    ),
                    const SizedBox(height: MadeenSpace.xxs),
                    Text(
                      '${plan.programName} · '
                      '${l10n.plansDuration(plan.durationDays)}',
                      style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: MadeenSpace.sm),
              Text(
                plan.isFree
                    ? l10n.plansFree
                    : formatMoney(plan.priceCents, plan.currency),
                style: MadeenType.headlineSm.copyWith(color: t.accentText),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: MadeenSpace.xs),
            Text(description, style: MadeenType.bodyMd.copyWith(color: t.ink)),
          ],
          const SizedBox(height: MadeenSpace.md),
          Row(
            children: [
              if (hasAccess) ...[
                Icon(Icons.check_circle_outline, size: 18, color: t.success),
                const SizedBox(width: MadeenSpace.xxs),
                Expanded(
                  child: Text(
                    l10n.plansHasAccess,
                    style: MadeenType.bodySm.copyWith(color: t.success),
                  ),
                ),
              ] else
                const Spacer(),
              OutlinedButton(
                onPressed: () async {
                  final activated = await showCouponSheet(context, plan);
                  if (activated && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.couponActivated)),
                    );
                  }
                },
                child: Text(l10n.plansUseCoupon),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
