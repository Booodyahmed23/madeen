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
// Reusing Curriculum's Program/Part read models and providers for the
// picker below is a deliberate, real reuse case (Program/Part are
// canonical curriculum data, not exam-specific business logic) — not a
// case of duplicating another feature's internals. Nothing about
// Curriculum's own screens or behavior changes because of this.
import '../../../curriculum/domain/entities/part.dart';
import '../../../curriculum/domain/entities/program.dart';
import '../../../curriculum/domain/entities/sub_unit.dart';
import '../../../curriculum/domain/entities/unit.dart';
import '../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../subscription/presentation/widgets/no_access_notice.dart';
import '../../domain/entities/exam_config.dart';
import '../providers/exam_notifier.dart';
import '../providers/exam_state.dart';

/// Exam Simulation's entry point — reached from Home (see
/// AppRoutes.examSetup), not from a Curriculum Topic like Study Session.
/// Configuration is scoped to Program + Part, the level real exams are
/// organized at, optionally narrowed to one Unit and Sub-unit. The time
/// limit is not chosen separately: it follows from the question count (see
/// [examDurationFor]) — both mobile-side placeholder presets until the
/// backend defines the real values (docs/MOBILE_API_CONTRACT.md §A4).
class ExamSetupScreen extends ConsumerStatefulWidget {
  const ExamSetupScreen({super.key});

  @override
  ConsumerState<ExamSetupScreen> createState() => _ExamSetupScreenState();
}

class _ExamSetupScreenState extends ConsumerState<ExamSetupScreen> {
  Program? _selectedProgram;
  Part? _selectedPart;

  /// `null` = the whole Part.
  Unit? _selectedUnit;

  /// `null` = the whole Unit.
  SubUnit? _selectedSubUnit;

  /// Whether the default program (the student's first entitlement) has
  /// been preselected — done once, so it never overrides the user's pick.
  bool _defaultProgramApplied = false;
  int _questionCount = kExamQuestionCountOptions.first;
  ExamDifficulty? _difficulty;

  /// Set when the selected scope has no topics with questions — nothing to
  /// start, so the API isn't called.
  bool _scopeHasNoQuestions = false;

  void _applyDefaultProgram(List<Program> programs) {
    if (_defaultProgramApplied || _selectedProgram != null) return;
    final defaultId = ref.watch(defaultProgramIdProvider).value;
    if (defaultId == null) return;
    _defaultProgramApplied = true;
    for (final program in programs) {
      if (program.id == defaultId) _selectedProgram = program;
    }
  }

  void _start() {
    final program = _selectedProgram;
    final part = _selectedPart;
    if (program == null || part == null) return;
    final tree = ref.read(programTreeProvider(program.id)).value;
    if (tree == null) return;
    final topicIds = tree.topicIdsUnder(
      _selectedSubUnit?.id ?? _selectedUnit?.id ?? part.id,
    );
    if (topicIds.isEmpty) {
      setState(() => _scopeHasNoQuestions = true);
      return;
    }
    setState(() => _scopeHasNoQuestions = false);

    ref
        .read(examNotifierProvider.notifier)
        .startExam(
          ExamConfig(
            programId: program.id,
            programName: program.name,
            partId: part.id,
            partName: part.name,
            unitId: _selectedUnit?.id,
            unitName: _selectedUnit?.name,
            subUnitId: _selectedSubUnit?.id,
            subUnitName: _selectedSubUnit?.name,
            questionCount: _questionCount,
            duration: examDurationFor(_questionCount),
            topicIds: topicIds,
            difficulty: _difficulty,
            topicNames: {
              for (final id in topicIds) id: tree.topicById(id)?.name ?? id,
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(examNotifierProvider);
    final programsAsync = ref.watch(programsProvider);

    ref.listen<ExamState>(examNotifierProvider, (previous, next) {
      if (next is ExamActive && previous is! ExamActive) {
        context.push(AppRoutes.examActive);
      }
    });

    final isLoading = state is ExamLoading;
    final failure = state is ExamError ? state.failure : null;
    // Known "no plan" (or the server said so on start) blocks starting; while
    // access is loading or couldn't be checked, the server stays the judge.
    final noAccess =
        ref.watch(hasAccessProvider).value == false ||
        failure is NoAccessFailure;
    final canStart =
        !noAccess && _selectedProgram != null && _selectedPart != null;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.examSetupTitle)),
      body: SafeArea(
        child: Column(
          children: [
            SampleDataBanner(
              isSampleData: !AppConfig.isExamSimulationApiAvailable,
              message: l10n.examSampleDataNotice,
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
                  MadeenSectionHeader(title: l10n.examSetupProgramLabel),
                  const SizedBox(height: MadeenSpace.sm),
                  programsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, _) => Text(l10n.examGenericError),
                    data: (programs) {
                      _applyDefaultProgram(programs);
                      return DropdownButtonFormField<Program>(
                        key: ValueKey('exam-program-${_selectedProgram?.id}'),
                        initialValue: _selectedProgram,
                        hint: Text(l10n.examSetupSelectProgramHint),
                        isExpanded: true,
                        items: programs
                            .map(
                              (program) => DropdownMenuItem(
                                value: program,
                                child: Text(program.name),
                              ),
                            )
                            .toList(),
                        onChanged: (program) => setState(() {
                          _selectedProgram = program;
                          _selectedPart = null;
                          _selectedUnit = null;
                          _selectedSubUnit = null;
                        }),
                      );
                    },
                  ),
                  const SizedBox(height: MadeenSpace.xl),

                  MadeenSectionHeader(title: l10n.examSetupPartLabel),
                  const SizedBox(height: MadeenSpace.sm),
                  if (_selectedProgram == null)
                    Text(
                      l10n.examSetupSelectPartHint,
                      style: MadeenType.bodyMd.copyWith(
                        color: MadeenTokens.of(context).inkSecondary,
                      ),
                    )
                  else
                    Consumer(
                      builder: (context, ref, _) {
                        final partsAsync = ref.watch(
                          partsProvider(_selectedProgram!.id),
                        );
                        return partsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (error, _) => Text(l10n.examGenericError),
                          data: (parts) => DropdownButtonFormField<Part>(
                            initialValue: _selectedPart,
                            hint: Text(l10n.examSetupSelectPartHint),
                            isExpanded: true,
                            items: parts
                                .map(
                                  (part) => DropdownMenuItem(
                                    value: part,
                                    child: Text(part.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (part) => setState(() {
                              _selectedPart = part;
                              _selectedUnit = null;
                              _selectedSubUnit = null;
                              _scopeHasNoQuestions = false;
                            }),
                          ),
                        );
                      },
                    ),
                  const SizedBox(height: MadeenSpace.xl),

                  if (_selectedPart != null) ..._scopeSection(l10n),

                  MadeenSectionHeader(title: l10n.examSetupQuestionCountLabel),
                  const SizedBox(height: MadeenSpace.sm),
                  MadeenChoicePills<int>(
                    choices: [
                      for (final count in kExamQuestionCountOptions)
                        MadeenChoice(value: count, label: '$count'),
                    ],
                    selected: _questionCount,
                    onSelected: (count) =>
                        setState(() => _questionCount = count),
                  ),
                  const SizedBox(height: MadeenSpace.sm),
                  _TimeLimitRow(
                    label: l10n.examSetupTimeLimitLabel,
                    value: _formatDuration(
                      l10n,
                      examDurationFor(_questionCount),
                    ),
                  ),
                  const SizedBox(height: MadeenSpace.xl),

                  MadeenSectionHeader(title: l10n.setupDifficultyLabel),
                  const SizedBox(height: MadeenSpace.sm),
                  MadeenChoicePills<ExamDifficulty?>(
                    choices: [
                      MadeenChoice(value: null, label: l10n.setupDifficultyAny),
                      MadeenChoice(
                        value: ExamDifficulty.easy,
                        label: l10n.setupDifficultyEasy,
                      ),
                      MadeenChoice(
                        value: ExamDifficulty.medium,
                        label: l10n.setupDifficultyMedium,
                      ),
                      MadeenChoice(
                        value: ExamDifficulty.hard,
                        label: l10n.setupDifficultyHard,
                      ),
                    ],
                    selected: _difficulty,
                    onSelected: (value) => setState(() => _difficulty = value),
                  ),
                  const SizedBox(height: MadeenSpace.xl),

                  _ExamRulesNote(
                    title: l10n.examSetupRulesTitle,
                    body: l10n.examSetupRulesBody,
                  ),

                  if (noAccess) ...[
                    const SizedBox(height: MadeenSpace.md),
                    const NoAccessNotice(),
                  ] else if (_scopeHasNoQuestions ||
                      (failure != null && _isNoQuestions(failure))) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.examSetupNoQuestions,
                      style: MadeenType.bodySm.copyWith(
                        color: MadeenTokens.of(context).error,
                      ),
                    ),
                  ] else if (failure != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      localizedFailureMessage(l10n, failure),
                      style: MadeenType.bodySm.copyWith(
                        color: MadeenTokens.of(context).error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            MadeenBottomActionBar(
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(MadeenSize.buttonHeight),
                ),
                onPressed: (isLoading || !canStart) ? null : _start,
                child: isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(l10n.examSetupStarting),
                        ],
                      )
                    : Text(l10n.examSetupStartButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Unit and Sub-unit pickers — optional narrowing of the Part. Shown
  /// only when the selected level actually has children to pick from.
  List<Widget> _scopeSection(AppLocalizations l10n) {
    final part = _selectedPart!;
    final programId = part.programId;
    final unitsAsync = ref.watch(
      unitsProvider((programId: programId, partId: part.id)),
    );
    final units = unitsAsync.value ?? const <Unit>[];
    final unit = _selectedUnit;
    final subUnits = unit == null
        ? const <SubUnit>[]
        : ref
                  .watch(
                    subUnitsProvider((programId: programId, unitId: unit.id)),
                  )
                  .value ??
              const <SubUnit>[];

    return [
      if (unitsAsync.isLoading) ...[
        const LinearProgressIndicator(),
        const SizedBox(height: MadeenSpace.xl),
      ],
      if (units.isNotEmpty) ...[
        MadeenSectionHeader(title: l10n.examSetupUnitLabel),
        const SizedBox(height: MadeenSpace.sm),
        DropdownButtonFormField<Unit?>(
          key: ValueKey('exam-unit-${part.id}'),
          initialValue: unit,
          isExpanded: true,
          items: [
            DropdownMenuItem(child: Text(l10n.examSetupAllUnits)),
            for (final u in units)
              DropdownMenuItem(value: u, child: Text(u.name)),
          ],
          onChanged: (value) => setState(() {
            _selectedUnit = value;
            _selectedSubUnit = null;
            _scopeHasNoQuestions = false;
          }),
        ),
        const SizedBox(height: MadeenSpace.xl),
      ],
      if (subUnits.isNotEmpty) ...[
        MadeenSectionHeader(title: l10n.examSetupSubUnitLabel),
        const SizedBox(height: MadeenSpace.sm),
        DropdownButtonFormField<SubUnit?>(
          key: ValueKey('exam-subunit-${unit!.id}'),
          initialValue: _selectedSubUnit,
          isExpanded: true,
          items: [
            DropdownMenuItem(child: Text(l10n.examSetupAllSubUnits)),
            for (final s in subUnits)
              DropdownMenuItem(value: s, child: Text(s.name)),
          ],
          onChanged: (value) => setState(() {
            _selectedSubUnit = value;
            _scopeHasNoQuestions = false;
          }),
        ),
        const SizedBox(height: MadeenSpace.xl),
      ],
    ];
  }

  String _formatDuration(AppLocalizations l10n, Duration duration) {
    if (duration.inMinutes < 60) {
      return l10n.examSetupDurationMinutes(duration.inMinutes);
    }
    if (duration.inMinutes % 60 == 0) {
      return l10n.examSetupDurationHours(duration.inHours);
    }
    return l10n.examSetupDurationMinutes(duration.inMinutes);
  }
}

/// The time limit that follows from the chosen question count — read-only.
class _TimeLimitRow extends StatelessWidget {
  const _TimeLimitRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Row(
      children: [
        Icon(Icons.timer_outlined, size: 18, color: t.inkSecondary),
        const SizedBox(width: MadeenSpace.xs),
        Flexible(
          child: Text(
            label,
            style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
          ),
        ),
        const SizedBox(width: MadeenSpace.xs),
        Text(
          value,
          style: MadeenType.bodyMd.copyWith(
            color: t.ink,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Sets expectations before the clock starts: exam conditions differ from
/// Study Session in ways the student should know up front.
class _ExamRulesNote extends StatelessWidget {
  const _ExamRulesNote({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return MadeenCard(
      tone: MadeenCardTone.muted,
      padding: const EdgeInsets.all(MadeenSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MadeenSectionHeader(title: title, icon: Icons.gavel_outlined),
          const SizedBox(height: MadeenSpace.xs),
          Text(body, style: MadeenType.bodySm.copyWith(color: t.ink)),
        ],
      ),
    );
  }
}

/// The API's `400` when no published question matches (contract §A4).
bool _isNoQuestions(AppFailure failure) =>
    failure is ValidationFailure &&
    failure.message.startsWith('No published questions');
