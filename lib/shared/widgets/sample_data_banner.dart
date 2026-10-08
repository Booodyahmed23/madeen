import 'package:flutter/material.dart';

import 'madeen/madeen.dart';

/// Visible, unmissable reminder that the content on screen is local sample
/// data, not real backend content — every feature whose backend doesn't
/// exist yet (Curriculum in Phase 3, Study Session in Phase 4) uses this
/// with its own `AppConfig.is*ApiAvailable` flag and message. Never omit
/// this when `isSampleData` is true: showing sample data with no indication
/// it isn't real would be presenting a mock as production-ready.
class SampleDataBanner extends StatelessWidget {
  const SampleDataBanner({
    super.key,
    required this.isSampleData,
    required this.message,
  });

  final bool isSampleData;
  final String message;

  @override
  Widget build(BuildContext context) {
    if (!isSampleData) return const SizedBox.shrink();

    // A quiet MADEEN notice strip: neutral fill, a hairline beneath, a
    // brass info mark — visible without competing with the content.
    final t = MadeenTokens.of(context);
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: t.neutralFill,
          border: Border(bottom: BorderSide(color: t.hairline)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: MadeenSpace.pageMargin,
          vertical: MadeenSpace.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 18, color: t.accentText),
            const SizedBox(width: MadeenSpace.xs),
            Expanded(
              child: Text(
                message,
                style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
