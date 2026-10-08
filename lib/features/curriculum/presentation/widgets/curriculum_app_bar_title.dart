import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';

/// AppBar title for every curriculum level below Programs: the level label
/// ("Parts", "Units", ...) plus a single line of immediate-parent context
/// ("in CMA") — not a full breadcrumb chain, per the UX guidance to keep
/// context minimal on mobile (mirrors the Study Session screen's "show the
/// topic, not the full path" rule in ARCHITECTURE.md §10.2).
class CurriculumAppBarTitle extends StatelessWidget {
  const CurriculumAppBarTitle({
    super.key,
    required this.label,
    this.parentName,
  });

  final String label;
  final String? parentName;

  @override
  Widget build(BuildContext context) {
    if (parentName == null || parentName!.isEmpty) {
      return Text(label);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(
          AppLocalizations.of(context)!.curriculumContextSubtitle(parentName!),
          style: MadeenType.bodySm.copyWith(
            color: MadeenTokens.of(context).inkSecondary,
          ),
        ),
      ],
    );
  }
}
