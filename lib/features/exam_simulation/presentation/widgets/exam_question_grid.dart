import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';

/// How one question cell is drawn. Correctness is deliberately *not* a
/// state here — during the exam only "answered or not" exists.
class ExamQuestionCellState {
  const ExamQuestionCellState({
    required this.isAnswered,
    this.isCurrent = false,
    this.isFlagged = false,
  });

  final bool isAnswered;
  final bool isCurrent;
  final bool isFlagged;
}

/// A wrap of numbered question cells — the exam's question navigator.
/// Every state is told apart by more than color: answered cells are filled,
/// unanswered are outlined, the current one sits inside a separate brass
/// ring (a gap keeps it distinct even on a filled, brass dark-mode cell),
/// and flagged ones a flag glyph — and each cell has a full spoken label.
class ExamQuestionGrid extends StatelessWidget {
  const ExamQuestionGrid({
    super.key,
    required this.count,
    required this.stateFor,
    required this.onSelected,
    this.numberFor,
  });

  final int count;
  final ExamQuestionCellState Function(int index) stateFor;
  final ValueChanged<int> onSelected;

  /// The 1-based number printed in cell [index] (defaults to `index + 1`) —
  /// lets a filtered list (e.g. only wrong answers) keep exam numbering.
  final int Function(int index)? numberFor;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: MadeenSpace.xxs,
      runSpacing: MadeenSpace.xxs,
      children: [
        for (var i = 0; i < count; i++)
          ExamQuestionCell(
            number: numberFor?.call(i) ?? i + 1,
            state: stateFor(i),
            onTap: () => onSelected(i),
          ),
      ],
    );
  }
}

class ExamQuestionCell extends StatelessWidget {
  const ExamQuestionCell({
    super.key,
    required this.number,
    required this.state,
    required this.onTap,
  });

  /// Outer size, including the space reserved for the current-question ring.
  static const double size = 48;

  final int number;
  final ExamQuestionCellState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final status = [
      if (state.isCurrent) l10n.examNavigatorCurrent,
      state.isAnswered
          ? l10n.examQuestionStatusAnswered
          : l10n.examQuestionStatusUnanswered,
      if (state.isFlagged) l10n.examQuestionStatusFlagged,
    ].join(', ');

    final background = state.isAnswered ? t.primaryAction : t.surface;
    final foreground = state.isAnswered ? t.onPrimaryAction : t.ink;
    final border = BorderSide(
      color: state.isAnswered ? t.primaryAction : t.hairline,
    );

    return Semantics(
      // Its own node: each cell is a separate screen-reader target, never
      // merged into the surrounding card's label.
      container: true,
      button: true,
      selected: state.isCurrent,
      label: l10n.examNavigatorCellSemantic(number, status),
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MadeenRadius.base + 3),
          border: Border.all(
            color: state.isCurrent ? t.accent : Colors.transparent,
            width: 2,
          ),
        ),
        child: Material(
          color: background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(MadeenRadius.base),
            side: border,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$number',
                    style: MadeenType.labelMd.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                if (state.isFlagged)
                  PositionedDirectional(
                    top: 2,
                    end: 2,
                    child: Icon(Icons.flag, size: 12, color: t.attention),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The key under the grid: one swatch per cell state.
class ExamQuestionGridLegend extends StatelessWidget {
  const ExamQuestionGridLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);

    Widget swatch({
      required String label,
      required Color fill,
      required BorderSide side,
      IconData? icon,
    }) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(MadeenRadius.base / 2),
            border: Border.fromBorderSide(side),
          ),
          child: icon == null ? null : Icon(icon, size: 11, color: t.attention),
        ),
        const SizedBox(width: MadeenSpace.xxs + 2),
        Text(label, style: MadeenType.bodySm.copyWith(color: t.inkSecondary)),
      ],
    );

    return Wrap(
      spacing: MadeenSpace.md,
      runSpacing: MadeenSpace.xs,
      children: [
        swatch(
          label: l10n.examNavigatorCurrent,
          fill: t.surface,
          side: BorderSide(color: t.accent, width: 2),
        ),
        swatch(
          label: l10n.examQuestionStatusAnswered,
          fill: t.primaryAction,
          side: BorderSide(color: t.primaryAction),
        ),
        swatch(
          label: l10n.examQuestionStatusUnanswered,
          fill: t.surface,
          side: BorderSide(color: t.hairline),
        ),
        swatch(
          label: l10n.examQuestionStatusFlagged,
          fill: t.surface,
          side: BorderSide(color: t.hairline),
          icon: Icons.flag,
        ),
      ],
    );
  }
}
