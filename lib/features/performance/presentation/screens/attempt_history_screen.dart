import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import '../../../../core/error/failure_messages.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../providers/attempt_history_notifier.dart';
import '../providers/attempt_history_state.dart';
import '../widgets/attempt_summary_tile.dart';
import '../widgets/attempt_type_filter_bar.dart';

/// Full, paginated Attempt History — most recent first, with an All /
/// Study Session / Exam Simulation filter shared with the Overview screen.
class AttemptHistoryScreen extends ConsumerWidget {
  const AttemptHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(attemptHistoryNotifierProvider);
    final notifier = ref.read(attemptHistoryNotifierProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.performanceAttemptsTitle)),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isPerformanceApiAvailable,
            message: l10n.performanceSampleDataNotice,
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(
              MadeenSpace.pageMargin,
              MadeenSpace.md,
              MadeenSpace.pageMargin,
              MadeenSpace.xs,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: AttemptTypeFilterBar(),
            ),
          ),
          Expanded(
            child: _Body(state: state, notifier: notifier, l10n: l10n),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.notifier,
    required this.l10n,
  });

  final AttemptHistoryState state;
  final AttemptHistoryNotifier notifier;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      AttemptHistoryInitial() ||
      AttemptHistoryLoading() => const MadeenPageLoading(),
      AttemptHistoryError(:final failure) => _ErrorView(
        failure: failure,
        l10n: l10n,
        onRetry: notifier.retry,
      ),
      AttemptHistoryReady(:final items) when items.isEmpty => MadeenPageMessage(
        message: l10n.performanceNoAttempts,
      ),
      AttemptHistoryReady(:final items, :final hasMore, :final isLoadingMore) =>
        RefreshIndicator(
          onRefresh: notifier.load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              MadeenSpace.pageMargin,
              0,
              MadeenSpace.pageMargin,
              MadeenSpace.xl,
            ),
            itemCount: items.length + (hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const Divider(),
            itemBuilder: (context, index) {
              if (index >= items.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: MadeenSpace.md),
                  child: Center(
                    child: isLoadingMore
                        ? const MadeenLoadingState()
                        : MadeenSecondaryButton(
                            label: l10n.performanceLoadMoreButton,
                            onPressed: notifier.loadMore,
                          ),
                  ),
                );
              }
              final attempt = items[index];
              return AttemptSummaryTile(
                attempt: attempt,
                onTap: () => context.push(
                  AppRoutes.performanceAttemptDetail(attempt.attemptId),
                ),
              );
            },
          ),
        ),
    };
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.failure,
    required this.l10n,
    required this.onRetry,
  });

  final AppFailure failure;
  final AppLocalizations l10n;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MadeenPageMessage(
      message: localizedFailureMessage(AppLocalizations.of(context)!, failure),
      isError: true,
      actionLabel: l10n.performanceRetryButton,
      onAction: onRetry,
    );
  }
}
