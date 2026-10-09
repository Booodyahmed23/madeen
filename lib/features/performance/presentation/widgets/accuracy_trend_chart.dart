import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/trend_day.dart';

/// Daily accuracy as one column per day (contract §A8 B8). One series, so no
/// legend — the section title names it. Recessive guides at 0/50/100%, a
/// rounded 4px top on each bar, a direct label on the latest day only, and
/// a tooltip + screen-reader label on every day. A day with no answers has
/// no bar (a dash), never a zero-height one that reads as 0%.
class AccuracyTrendChart extends StatelessWidget {
  const AccuracyTrendChart({super.key, required this.days});

  final List<TrendDay> days;

  static const _plotHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final locale = Localizations.localeOf(context).toString();
    final answered = days.fold<int>(0, (sum, d) => sum + d.total);
    final correct = days.fold<int>(0, (sum, d) => sum + d.correct);

    if (answered == 0) {
      return MadeenEmptyState(message: l10n.performanceTrendEmpty);
    }

    String dayName(TrendDay day) => DateFormat.E(locale).format(day.date);
    String describe(TrendDay day) {
      final full = DateFormat.MMMEd(locale).format(day.date);
      final accuracy = day.accuracyPercent;
      return accuracy == null
          ? l10n.performanceTrendDayEmpty(full)
          : l10n.performanceTrendDay(
              full,
              accuracy.round(),
              day.correct,
              day.total,
            );
    }

    final latestWithData = days.lastIndexWhere(
      (d) => d.accuracyPercent != null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The headline: the week in one number.
        Text(
          l10n.performanceTrendSummary(
            (correct / answered * 100).round(),
            answered,
          ),
          style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
        ),
        const SizedBox(height: MadeenSpace.md),
        SizedBox(
          height: _plotHeight + 20,
          child: Stack(
            children: [
              // Recessive guides at 100%, 50% and the 0% baseline.
              for (final fraction in const [1.0, 0.5, 0.0])
                Positioned(
                  left: 0,
                  right: 0,
                  top: 20 + (_plotHeight - 1) * (1 - fraction),
                  child: Container(
                    height: 1,
                    color: fraction == 0 ? t.inkTertiary : t.hairline,
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (index, day) in days.indexed)
                    Expanded(
                      child: Tooltip(
                        message: describe(day),
                        triggerMode: TooltipTriggerMode.tap,
                        child: Semantics(
                          label: describe(day),
                          excludeSemantics: true,
                          child: _Column(
                            day: day,
                            plotHeight: _plotHeight,
                            showValue: index == latestWithData,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: MadeenSpace.xs),
        Row(
          children: [
            for (final day in days)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    dayName(day),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Column extends StatelessWidget {
  const _Column({
    required this.day,
    required this.plotHeight,
    required this.showValue,
  });

  final TrendDay day;
  final double plotHeight;
  final bool showValue;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final accuracy = day.accuracyPercent;
    return Padding(
      // A 2px surface gap each side between neighbouring bars.
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SizedBox(
            height: 20,
            child: showValue && accuracy != null
                ? Text(
                    '${accuracy.round()}%',
                    style: MadeenType.bodySm.copyWith(
                      color: t.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
          if (accuracy == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '–',
                style: MadeenType.bodySm.copyWith(color: t.inkTertiary),
              ),
            )
          else
            Container(
              width: 18,
              // A 0% day still shows a 2px stub, so it reads as "0%", not
              // as "no answers".
              height: (plotHeight * accuracy / 100).clamp(2, plotHeight),
              decoration: BoxDecoration(
                color: t.dataMark,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
