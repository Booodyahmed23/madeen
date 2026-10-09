import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../subscription/presentation/widgets/no_access_notice.dart';
import '../../domain/entities/session_config.dart';
import '../providers/study_session_notifier.dart';
import '../providers/study_session_state.dart';

/// Reached from Curriculum: a Topic (see AppRoutes.curriculumTopicDetail),
/// a whole sub-unit's topics, or "all my topics" (AppRoutes.studySessionSetup
/// — no topic ids). The scope is read-only context here — Curriculum
/// browsing already covers choosing content.
class StudySessionSetupScreen extends ConsumerStatefulWidget {
  const StudySessionSetupScreen({
    super.key,
    this.topicId,
    this.topicIds = const [],
    this.topicName,
  });

  /// One topic, or [topicIds] for several; neither = all my topics.
  final String? topicId;
  final List<String> topicIds;
  final String? topicName;

  @override
  ConsumerState<StudySessionSetupScreen> createState() =>
      _StudySessionSetupScreenState();
}

class _StudySessionSetupScreenState
    extends ConsumerState<StudySessionSetupScreen> {
  int _questionCount = kQuestionCountOptions.first;
  FeedbackMode _feedbackMode = FeedbackMode.immediate;
  QuestionDifficulty? _difficulty;

  List<String> get _topicIds =>
      widget.topicIds.isNotEmpty ? widget.topicIds : [?widget.topicId];

  String _topicDisplayName(AppLocalizations l10n) =>
      widget.topicName ??
      (_topicIds.isEmpty ? l10n.studySessionAllMyTopics : _topicIds.first);

  void _start() {
    ref
        .read(studySessionNotifierProvider.notifier)
        .startSession(
          SessionConfig(
            topicIds: _topicIds,
            topicName: _topicDisplayName(AppLocalizations.of(context)!),
            questionCount: _questionCount,
            feedbackMode: _feedbackMode,
            difficulty: _difficulty,
          ),
        );
  }

  /// Any count from 1 to 100 (contract §A3), beyond the presets.
  Future<void> _pickCustomCount() async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => _CustomCountDialog(initial: _questionCount),
    );
    if (count != null && mounted) setState(() => _questionCount = count);
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
    // Known "no plan" (or the server said so on start) blocks starting; while
    // access is loading or couldn't be checked, the server stays the judge.
    final noAccess =
        ref.watch(hasAccessProvider).value == false ||
        failure is NoAccessFailure;

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
                    _topicDisplayName(l10n),
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
                    children: [
                      for (final count in kQuestionCountOptions)
                        ChoiceChip(
                          label: Text('$count'),
                          selected: _questionCount == count,
                          onSelected: (_) =>
                              setState(() => _questionCount = count),
                        ),
                      ChoiceChip(
                        label: Text(
                          kQuestionCountOptions.contains(_questionCount)
                              ? l10n.studySessionSetupCustomCount
                              : '${l10n.studySessionSetupCustomCount} '
                                    '($_questionCount)',
                        ),
                        selected: !kQuestionCountOptions.contains(
                          _questionCount,
                        ),
                        onSelected: (_) => _pickCustomCount(),
                      ),
                    ],
                  ),
                  const SizedBox(height: MadeenSpace.xl),
                  MadeenSectionHeader(title: l10n.setupDifficultyLabel),
                  const SizedBox(height: MadeenSpace.sm),
                  MadeenChoicePills<QuestionDifficulty?>(
                    choices: [
                      MadeenChoice(value: null, label: l10n.setupDifficultyAny),
                      MadeenChoice(
                        value: QuestionDifficulty.easy,
                        label: l10n.setupDifficultyEasy,
                      ),
                      MadeenChoice(
                        value: QuestionDifficulty.medium,
                        label: l10n.setupDifficultyMedium,
                      ),
                      MadeenChoice(
                        value: QuestionDifficulty.hard,
                        label: l10n.setupDifficultyHard,
                      ),
                    ],
                    selected: _difficulty,
                    onSelected: (value) => setState(() => _difficulty = value),
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
                  if (noAccess) ...[
                    const SizedBox(height: MadeenSpace.md),
                    const NoAccessNotice(),
                  ] else if (failure != null) ...[
                    const SizedBox(height: MadeenSpace.md),
                    Text(
                      _isNoQuestions(failure)
                          ? l10n.studySessionNoQuestions
                          : localizedFailureMessage(l10n, failure),
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
                  onPressed: isLoading || noAccess ? null : _start,
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

/// The API's `400` when the topic has no published questions (contract §A3).
bool _isNoQuestions(AppFailure failure) =>
    failure is ValidationFailure &&
    failure.message.startsWith('No published questions');

/// Asks for a question count from [kMinQuestionCount] to
/// [kMaxQuestionCount]; pops it, or nothing on cancel. Owns its text
/// controller, so it lives exactly as long as the dialog.
class _CustomCountDialog extends StatefulWidget {
  const _CustomCountDialog({required this.initial});

  final int initial;

  @override
  State<_CustomCountDialog> createState() => _CustomCountDialogState();
}

class _CustomCountDialogState extends State<_CustomCountDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}');
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pop(int.parse(_controller.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.studySessionSetupCustomCountTitle),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            helperText: l10n.studySessionSetupCustomCountHint,
          ),
          validator: (value) {
            final n = int.tryParse(value ?? '');
            return n == null || n < kMinQuestionCount || n > kMaxQuestionCount
                ? l10n.studySessionSetupCustomCountHint
                : null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.authCancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.studySessionSetupCustomCountConfirm),
        ),
      ],
    );
  }
}
