import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/exam_review_item.dart';
import '../providers/exam_notifier.dart';
import '../providers/exam_state.dart';

/// Which questions the post-exam review lists.
enum ExamReviewView {
  all,
  wrong,
  unanswered;

  /// From the route's `show` query parameter; anything unknown is [all].
  static ExamReviewView fromQuery(String? value) => switch (value) {
    'wrong' => ExamReviewView.wrong,
    'unanswered' => ExamReviewView.unanswered,
    _ => ExamReviewView.all,
  };

  String toQuery() => name;

  bool includes(ExamReviewItem item) => switch (this) {
    ExamReviewView.all => true,
    ExamReviewView.wrong => item.isWrong,
    ExamReviewView.unanswered => item.isUnanswered,
  };
}

/// Per-question review after submission — everything shown here comes from
/// the backend-sourced [ExamReviewItem] list, never recomputed from what
/// was (deliberately never) shown during the exam. This is the first place
/// a question's correct answer, explanation and topic are ever revealed.
class ExamPostReviewScreen extends ConsumerStatefulWidget {
  const ExamPostReviewScreen({
    super.key,
    this.initialView = ExamReviewView.all,
    this.focusQuestionId,
  });

  final ExamReviewView initialView;

  /// Scrolled into view on first build (e.g. a question tapped on Results).
  final String? focusQuestionId;

  @override
  ConsumerState<ExamPostReviewScreen> createState() =>
      _ExamPostReviewScreenState();
}

class _ExamPostReviewScreenState extends ConsumerState<ExamPostReviewScreen> {
  late ExamReviewView _view = widget.initialView;
  final _focusKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.focusQuestionId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final focusContext = _focusKey.currentContext;
        if (focusContext != null) {
          Scrollable.ensureVisible(
            focusContext,
            duration: const Duration(milliseconds: 250),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(examNotifierProvider);

    if (state is! ExamCompleted) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.examPostReviewTitle)),
        body: Center(child: Text(l10n.examGenericError)),
      );
    }

    if (state.review.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.examPostReviewTitle)),
        body: MadeenPageMessage(message: l10n.examPostReviewEmpty),
      );
    }

    // Exam numbering is kept in every view: "Question 7" stays 7 when only
    // wrong answers are listed.
    final visible = [
      for (var i = 0; i < state.review.length; i++)
        if (_view.includes(state.review[i]))
          (number: i + 1, item: state.review[i]),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.examPostReviewTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            MadeenSpace.pageMargin,
            MadeenSpace.md,
            MadeenSpace.pageMargin,
            MadeenSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MadeenChoicePills<ExamReviewView>(
                choices: [
                  MadeenChoice(
                    value: ExamReviewView.all,
                    label: l10n.examPostReviewFilterAll,
                  ),
                  MadeenChoice(
                    value: ExamReviewView.wrong,
                    label: l10n.examPostReviewFilterWrong,
                  ),
                  MadeenChoice(
                    value: ExamReviewView.unanswered,
                    label: l10n.examPostReviewFilterUnanswered,
                  ),
                ],
                selected: _view,
                onSelected: (view) => setState(() => _view = view),
              ),
              const SizedBox(height: MadeenSpace.md),
              if (visible.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: MadeenSpace.xl),
                  child: Text(
                    l10n.examPostReviewEmptyFilter,
                    textAlign: TextAlign.center,
                    style: MadeenType.bodyMd.copyWith(
                      color: MadeenTokens.of(context).inkSecondary,
                    ),
                  ),
                ),
              // A Column (not a lazy list): every card is built, so the
              // focused one can be scrolled to however far down it is.
              for (final entry in visible) ...[
                _ReviewCard(
                  key: entry.item.questionId == widget.focusQuestionId
                      ? _focusKey
                      : null,
                  item: entry.item,
                  number: entry.number,
                ),
                const SizedBox(height: MadeenSpace.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({super.key, required this.item, required this.number});

  final ExamReviewItem item;
  final int number;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    // Unanswered is its own, quieter state — not drawn as a wrong answer.
    final (statusIcon, statusColor, borderColor) = item.isCorrect
        ? (Icons.check_circle, t.success, t.success)
        : item.isUnanswered
        ? (Icons.remove_circle_outline, t.inkTertiary, t.hairline)
        : (Icons.cancel, t.error, t.error);

    String choiceText(String? choiceId) {
      if (choiceId == null) return l10n.examPostReviewNoAnswer;
      final match = item.choices.where((c) => c.id == choiceId);
      return match.isEmpty ? choiceId : match.first.text;
    }

    Widget field(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: MadeenSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: MadeenType.eyebrow(context).copyWith(color: t.inkSecondary),
          ),
          const SizedBox(height: 2),
          MadeenContentText(
            value,
            style: MadeenType.bodyMd.copyWith(color: t.ink),
          ),
        ],
      ),
    );

    final topicName = item.topicName;

    return Container(
      padding: const EdgeInsets.all(MadeenSpace.md),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(MadeenRadius.card),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (topicName != null) ...[
            Text(
              topicName.toUpperCase(),
              style: MadeenType.eyebrow(context).copyWith(color: t.accentText),
            ),
            const SizedBox(height: MadeenSpace.xs),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: MadeenSpace.xs),
              Expanded(
                child: MadeenContentText(
                  '$number. ${item.questionText}',
                  style: MadeenType.bodyMd.copyWith(
                    color: t.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (item.wasFlagged)
                Tooltip(
                  message: l10n.examPostReviewFlaggedDuringExam,
                  child: Icon(Icons.flag, size: 18, color: t.attention),
                ),
            ],
          ),
          field(
            l10n.examPostReviewYourAnswerLabel,
            choiceText(item.selectedChoiceId),
          ),
          field(
            l10n.examPostReviewCorrectAnswerLabel,
            choiceText(item.correctChoiceId),
          ),
          if (item.explanation != null && item.explanation!.isNotEmpty)
            field(l10n.examExplanationLabel, item.explanation!),
        ],
      ),
    );
  }
}
