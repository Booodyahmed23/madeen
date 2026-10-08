import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';
import '../../../core/theme/madeen_typography.dart';
import 'madeen_content_text.dart';

/// The state a [MadeenChoiceTile] is drawn in.
enum MadeenChoiceState {
  /// Not chosen.
  neutral,

  /// Chosen by the student, not (yet) graded.
  selected,

  /// Graded: this is the correct answer.
  correct,

  /// Graded: the student chose this and it is wrong.
  incorrect,
}

/// A multiple-choice answer option (DESIGN.md "MCQ Option Tiles"): a 1px
/// hairline tile with a lettered anchor (A, B, C …). Selected → brass
/// border, filled brass anchor and a check mark; correct → sage + check;
/// incorrect → terracotta + cross, the answer struck through. Every
/// non-neutral state carries an icon, so it never depends on color alone.
///
/// Shared by Study Session and Exam Simulation — each feature still decides
/// the state from its own (repository-sourced) data; this only draws it.
class MadeenChoiceTile extends StatelessWidget {
  const MadeenChoiceTile({
    super.key,
    required this.index,
    required this.text,
    required this.state,
    required this.onTap,
  });

  /// 0-based position — drawn as the anchor letter (0 → A).
  final int index;
  final String text;
  final MadeenChoiceState state;

  /// `null` makes the tile non-interactive (e.g. locked after feedback).
  final VoidCallback? onTap;

  static String letterFor(int index) => index >= 0 && index < 26
      ? String.fromCharCode(65 + index)
      : '${index + 1}';

  /// The tile draws its own letter; content that already starts with the
  /// same label ("A) …", "A. …") would otherwise show it twice.
  static String _withoutLeadingLabel(String text, String letter) {
    final match = RegExp('^${RegExp.escape(letter)}[).]\\s+').firstMatch(text);
    return match == null ? text : text.substring(match.end);
  }

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final letter = letterFor(index);
    final body = _withoutLeadingLabel(text, letter);

    final (
      Color border,
      Color anchorFill,
      Color anchorInk,
      IconData? mark,
    ) = switch (state) {
      MadeenChoiceState.neutral => (t.hairline, t.neutralFill, t.ink, null),
      MadeenChoiceState.selected => (
        t.accent,
        t.accent,
        t.onPrimaryAction,
        Icons.check_circle,
      ),
      MadeenChoiceState.correct => (
        t.success,
        t.success,
        t.surface,
        Icons.check_circle,
      ),
      MadeenChoiceState.incorrect => (
        t.error,
        t.error,
        t.surface,
        Icons.cancel,
      ),
    };
    final emphasized = state != MadeenChoiceState.neutral;

    return Semantics(
      button: onTap != null,
      selected: state == MadeenChoiceState.selected,
      label: '$letter. $body',
      excludeSemantics: true,
      child: Material(
        color: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MadeenRadius.base),
          side: BorderSide(color: border, width: emphasized ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: anchorFill,
                      borderRadius: BorderRadius.circular(
                        MadeenRadius.base / 2,
                      ),
                    ),
                    child: Text(
                      letter,
                      style: MadeenType.labelMd.copyWith(
                        color: anchorInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: MadeenSpace.sm),
                  Expanded(
                    // Answer content may be in another script than the UI
                    // (English questions in the Arabic app).
                    child: MadeenContentText(
                      body,
                      style: MadeenType.bodyMd.copyWith(
                        color: t.ink,
                        fontSize: 16,
                        decoration: state == MadeenChoiceState.incorrect
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: t.error,
                      ),
                    ),
                  ),
                  if (mark != null) ...[
                    const SizedBox(width: MadeenSpace.xs),
                    Icon(mark, size: 22, color: border),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
