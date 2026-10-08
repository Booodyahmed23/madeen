import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../domain/entities/coupon_quote.dart';
import '../../domain/entities/plan.dart';
import '../providers/subscription_providers.dart';
import 'money_format.dart';

/// Opens the coupon sheet for [plan]. Resolves to `true` when a plan was
/// activated.
Future<bool> showCouponSheet(BuildContext context, Plan plan) async {
  final activated = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CouponSheet(plan: plan),
  );
  return activated ?? false;
}

/// Checks a coupon against a plan (`POST /coupons/validate`), shows what it
/// does to the price, and — only when it makes the plan free — activates
/// it (`POST /coupons/redeem`). A partial discount can't be used yet: there
/// is no online payment (contract §A6).
class CouponSheet extends ConsumerStatefulWidget {
  const CouponSheet({super.key, required this.plan});

  final Plan plan;

  @override
  ConsumerState<CouponSheet> createState() => _CouponSheetState();
}

class _CouponSheetState extends ConsumerState<CouponSheet> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isBusy = false;
  CouponQuote? _quote;
  AppFailure? _failure;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  String get _code => _codeController.text.trim();

  Future<void> _check() async {
    if (_isBusy) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isBusy = true;
      _failure = null;
      _quote = null;
    });
    final result = await ref
        .read(subscriptionRepositoryProvider)
        .validateCoupon(code: _code, planId: widget.plan.id);
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      switch (result) {
        case Success(:final value):
          _quote = value;
        case Failure(:final failure):
          _failure = failure;
      }
    });
  }

  Future<void> _activate() async {
    final quote = _quote;
    if (_isBusy || quote == null || !quote.isRedeemable) return;
    setState(() {
      _isBusy = true;
      _failure = null;
    });
    final result = await ref
        .read(subscriptionRepositoryProvider)
        .redeemCoupon(code: quote.code, planId: widget.plan.id);
    if (!mounted) return;
    switch (result) {
      case Success():
        ref
          ..invalidate(entitlementsProvider)
          ..invalidate(subscriptionsProvider);
        Navigator.of(context).pop(true);
      case Failure(:final failure):
        setState(() {
          _isBusy = false;
          _failure = failure;
        });
    }
  }

  void _onCodeChanged(String _) {
    // A quote describes the code it was checked with.
    if (_quote != null || _failure != null) {
      setState(() {
        _quote = null;
        _failure = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final quote = _quote;
    final failure = _failure;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        0,
        MadeenSpace.pageMargin,
        MediaQuery.viewInsetsOf(context).bottom + MadeenSpace.lg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.plansUseCoupon,
              style: Theme.of(context).textTheme.headlineSmall!
                  .copyWith(color: t.ink),
            ),
            const SizedBox(height: MadeenSpace.xxs),
            Text(
              '${widget.plan.programName} · ${widget.plan.name}',
              style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
            ),
            const SizedBox(height: MadeenSpace.md),
            TextFormField(
              controller: _codeController,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.couponCodeLabel),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                return length < 3 || length > 40 ? l10n.couponCodeLength : null;
              },
              onChanged: _onCodeChanged,
              onFieldSubmitted: (_) => _check(),
            ),
            if (failure != null) ...[
              const SizedBox(height: MadeenSpace.sm),
              Text(
                localizedFailureMessage(l10n, failure),
                style: MadeenType.bodySm.copyWith(color: t.error),
              ),
            ],
            if (quote != null) ...[
              const SizedBox(height: MadeenSpace.md),
              _QuoteRow(
                label: l10n.couponPrice,
                value: formatMoney(quote.priceCents, quote.currency),
              ),
              _QuoteRow(
                label: l10n.couponDiscount,
                value: '− ${formatMoney(quote.amountOffCents, quote.currency)}',
              ),
              const Divider(),
              _QuoteRow(
                label: l10n.couponFinalPrice,
                value: quote.isRedeemable
                    ? l10n.plansFree
                    : formatMoney(quote.finalPriceCents, quote.currency),
                emphasized: true,
              ),
              if (!quote.isRedeemable) ...[
                const SizedBox(height: MadeenSpace.sm),
                Text(
                  l10n.errorCouponNotFree,
                  style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
                ),
              ],
            ],
            const SizedBox(height: MadeenSpace.lg),
            FilledButton(
              onPressed: _isBusy
                  ? null
                  : (quote != null && quote.isRedeemable ? _activate : _check),
              child: _isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      quote != null && quote.isRedeemable
                          ? l10n.couponActivate
                          : l10n.couponCheck,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final style = (emphasized ? MadeenType.headlineSm : MadeenType.bodyMd)
        .copyWith(color: t.ink);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MadeenSpace.xxs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
