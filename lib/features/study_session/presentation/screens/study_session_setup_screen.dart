import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../../domain/entities/session_config.dart';
import '../providers/study_session_notifier.dart';
import '../providers/study_session_state.dart';

/// Reached from a Topic in Curriculum (see AppRoutes.curriculumTopicDetail —
/// this screen's route is the "leaf" the Curriculum flow ends at). The topic
/// itself is read-only context here, not re-selectable — Curriculum browsing
/// already covers "respect the curriculum hierarchy" for content selection.
class StudySessionSetupScreen extends ConsumerStatefulWidget {
  const StudySessionSetupScreen({
    super.key,
    required this.topicId,
    this.topicName,
  });

  final String topicId;
  final String? topicName;

  @override
  ConsumerState<StudySessionSetupScreen> createState() =>
      _StudySessionSetupScreenState();
}

class _StudySessionSetupScreenState
    extends ConsumerState<StudySessionSetupScreen> {
  int _questionCount = kQuestionCountOptions.first;
  QuestionOrder _order = QuestionOrder.original;
  FeedbackMode _feedbackMode = FeedbackMode.immediate;

  String get _topicDisplayName => widget.topicName ?? widget.topicId;

  void _start() {
    ref
        .read(studySessionNotifierProvider.notifier)
        .startSession(
          SessionConfig(
            topicId: widget.topicId,
            topicName: _topicDisplayName,
            questionCount: _questionCount,
            order: _order,
            feedbackMode: _feedbackMode,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(studySessionNotifierProvider);

    ref.listen<StudySessionState>(studySessionNotifierProvider, (
      previous,
      next,
    ) {
      if (next is StudySessionActive && previous is! StudySessionActive) {
        context.push(AppRoutes.studySessionActive);
      }
    });

    final isLoading = state is StudySessionLoading;
    final failure = state is StudySessionError ? state.failure : null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.studySessionSetupTitle)),
      body: SafeArea(
        child: Column(
          children: [
            SampleDataBanner(
              isSampleData: !AppConfig.isStudySessionApiAvailable,
              message: l10n.studySessionSampleDataNotice,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  MadeenSpace.pageMargin,
                  MadeenSpace.lg,
                  MadeenSpace.pageMargin,
                  MadeenSpace.lg,
                ),
                children: [
                  MadeenSectionHeader(title: l10n.studySessionSetupTopicLabel),
                  const SizedBox(height: MadeenSpace.xs),
                  Text(
                    _topicDisplayName,
                    style: Theme.of(context).textTheme.headlineLarge!
                        .copyWith(color: MadeenTokens.of(context).ink),
                  ),
                  const SizedBox(height: MadeenSpace.xl),
                  MadeenSectionHeader(
                    title: l10n.studySessionSetupQuestionCountLabel,
                  ),
                  const SizedBox(height: MadeenSpace.sm),
                  Wrap(
                    spacing: MadeenSpace.xs,
                    runSpacing: MadeenSpace.xs,
                    children: kQuestionCountOptions
                        .map(
                          (count) => ChoiceChip(
                            label: Text('$count'),
                            selected: _questionCount == count,
                            onSelected: (_) =>
                                setState(() => _questionCount = count),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: MadeenSpace.xl),
                  MadeenSectionHeader(title: l10n.studySessionSetupOrderLabel),
                  const SizedBox(height: MadeenSpace.sm),
                  SegmentedButton<QuestionOrder>(
                    segments: [
                      ButtonSegment(
                        value: QuestionOrder.original,
                        label: Text(l10n.studySessionSetupOrderOriginal),
                      ),
                      ButtonSegment(
                        value: QuestionOrder.random,
                        label: Text(l10n.studySessionSetupOrderRandom),
                      ),
                    ],
                    selected: {_order},
                    onSelectionChanged: (selection) =>
                        setState(() => _order = selection.first),
                  ),
                  const SizedBox(height: MadeenSpace.xl),
                  MadeenSectionHeader(
                    title: l10n.studySessionSetupFeedbackModeLabel,
                  ),
                  const SizedBox(height: MadeenSpace.sm),
                  MadeenOptionTile(
                    title: l10n.studySessionSetupFeedbackImmediate,
                    description:
                        l10n.studySessionSetupFeedbackImmediateDescription,
                    selected: _feedbackMode == FeedbackMode.immediate,
                    onTap: () =>
                        setState(() => _feedbackMode = FeedbackMode.immediate),
                  ),
                  const SizedBox(height: MadeenSpace.sm),
                  MadeenOptionTile(
                    title: l10n.studySessionSetupFeedbackAtEnd,
                    description: l10n.studySessionSetupFeedbackAtEndDescription,
                    selected: _feedbackMode == FeedbackMode.atEnd,
                    onTap: () =>
                        setState(() => _feedbackMode = FeedbackMode.atEnd),
                  ),
                  if (failure != null) ...[
                    const SizedBox(height: MadeenSpace.md),
                    Text(
                      failure.message,
                      style: MadeenType.bodySm.copyWith(
                        color: MadeenTokens.of(context).error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            MadeenBottomActionBar(
              child: SizedBox(
                width: double.infinity,
                height: MadeenSize.buttonHeight,
                child: FilledButton(
                  onPressed: isLoading ? null : _start,
                  child: isLoading
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: MadeenSpace.sm),
                            Text(l10n.studySessionSetupStarting),
                          ],
                        )
                      : Text(l10n.studySessionSetupStartButton),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
