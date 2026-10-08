import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../domain/entities/answer_choice.dart';

/// One selectable choice in the active question. Three visual states:
/// - Plain (nothing selected / not this one)
/// - Selected (student picked it, not yet submitted or "at end" mode)
/// - Resolved (immediate-feedback mode, after submission — highlights the
///   correct choice green and, if it was the wrong pick, this one red)
///
/// Resolved styling is driven entirely by [isCorrectChoice]/[isSelected],
/// which the screen derives from the repository-sourced [QuestionFeedback]
/// — never guessed or computed locally.
class AnswerChoiceTile extends StatelessWidget {
  const AnswerChoiceTile({
    super.key,
    required this.choice,
    required this.isSelected,
    required this.onTap,
    this.isCorrectChoice,
    this.isLocked = false,
  });

  final AnswerChoice choice;
  final bool isSelected;
  final VoidCallback? onTap;

  /// Non-null only once feedback is available for this question (immediate
  /// mode, post-submit): true if this is the correct choice, false if it's
  /// a confirmed-wrong choice, absent otherwise.
  final bool? isCorrectChoice;

  /// True once the question has been submitted (immediate mode) — choices
  /// stop responding to taps.
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final state = isCorrectChoice == true
        ? MadeenChoiceState.correct
        : isCorrectChoice == false && isSelected
        ? MadeenChoiceState.incorrect
        : isSelected
        ? MadeenChoiceState.selected
        : MadeenChoiceState.neutral;

    return MadeenChoiceTile(
      index: choice.order,
      text: choice.text,
      state: state,
      onTap: isLocked ? null : onTap,
    );
  }
}
