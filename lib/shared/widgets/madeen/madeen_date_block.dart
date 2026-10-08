import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/madeen_tokens.dart';
import '../../../core/theme/madeen_typography.dart';

/// A calendar block — abbreviated weekday over the day of the month, on the
/// hero slate (the reference's milestone date). Locale-aware via `intl`.
class MadeenDateBlock extends StatelessWidget {
  const MadeenDateBlock({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final locale = Localizations.localeOf(context).toString();
    return ExcludeSemantics(
      child: Container(
        // At least 48 wide; may grow for long weekday names (Arabic has no
        // abbreviated weekday, e.g. "الأربعاء"), capped so the row's text
        // always keeps most of the width.
        constraints: const BoxConstraints(minWidth: 48, maxWidth: 72),
        padding: const EdgeInsets.symmetric(
          horizontal: MadeenSpace.xxs + 2,
          vertical: MadeenSpace.xs,
        ),
        decoration: BoxDecoration(
          color: t.hero,
          borderRadius: BorderRadius.circular(MadeenRadius.base),
          border: Border.all(color: t.heroBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                DateFormat.E(locale).format(date).toUpperCase(),
                maxLines: 1,
                style: MadeenType.labelSm.copyWith(color: t.heroAccent),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat.d(locale).format(date),
              style: MadeenType.metricMd.copyWith(color: t.onHero),
            ),
          ],
        ),
      ),
    );
  }
}
