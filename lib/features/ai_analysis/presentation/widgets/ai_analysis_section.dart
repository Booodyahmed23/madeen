import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

/// A titled group of rows — the same small heading-plus-list shape repeats
/// for every section on the AI Analysis screens (Strengths, Areas to
/// Improve, Topic Insights, Recurring Patterns, Recommended Next Steps), so
/// it is factored out once rather than five near-identical `Column`s.
class AiAnalysisSection extends StatelessWidget {
  const AiAnalysisSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MadeenSpace.md),
      child: MadeenCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MadeenSectionHeader(title: title),
            const SizedBox(height: MadeenSpace.sm),
            ...children,
          ],
        ),
      ),
    );
  }
}
