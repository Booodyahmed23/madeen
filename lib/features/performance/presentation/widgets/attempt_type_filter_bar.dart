import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/performance_filter.dart';
import '../providers/performance_filter_provider.dart';

/// All / Study Session / Exam Simulation — shared by Overview and Attempt
/// History so both stay in sync on the same [performanceFilterProvider]
/// selection.
class AttemptTypeFilterBar extends ConsumerWidget {
  const AttemptTypeFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selected = ref.watch(performanceFilterProvider).attemptType;

    return MadeenChoicePills<AttemptTypeFilter>(
      choices: [
        MadeenChoice(
          value: AttemptTypeFilter.all,
          label: l10n.performanceAllLabel,
        ),
        MadeenChoice(
          value: AttemptTypeFilter.studySession,
          label: l10n.performanceStudySessionLabel,
        ),
        MadeenChoice(
          value: AttemptTypeFilter.examSimulation,
          label: l10n.performanceExamSimulationLabel,
        ),
      ],
      selected: selected,
      onSelected: (value) =>
          ref.read(performanceFilterProvider.notifier).setAttemptType(value),
    );
  }
}
