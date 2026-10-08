import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../domain/entities/exam_answer_choice.dart';

/// One selectable choice during the active exam. Unlike Study Session's
/// `AnswerChoiceTile`, there is no "resolved" (correct/incorrect) visual
/// state at all — Exam Simulation never reveals correctness during the
/// exam, so this widget only ever communicates selected vs. not selected.
class ExamAnswerChoiceTile extends StatelessWidget {
  const ExamAnswerChoiceTile({
    super.key,
    required this.choice,
    required this.isSelected,
    required this.onTap,
  });

  final ExamAnswerChoice choice;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MadeenChoiceTile(
      index: choice.order,
      text: choice.text,
      state: isSelected
          ? MadeenChoiceState.selected
          : MadeenChoiceState.neutral,
      onTap: onTap,
    );
  }
}
