import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/async_list_view.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../../domain/entities/performance_filter.dart';
import '../../domain/entities/topic_performance.dart';
import '../providers/performance_filter_provider.dart';
import '../providers/performance_providers.dart';
import '../widgets/topic_performance_tile.dart';

/// Every topic the student has practiced, with a Strong / Needs Practice /
/// All filter — plain factual metrics only, no weighting algorithm (see
/// TopicPerformance's doc comment).
class TopicPerformanceScreen extends ConsumerWidget {
  const TopicPerformanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final topicsAsync = ref.watch(filteredTopicPerformanceProvider);
    final selectedFilter = ref.watch(performanceFilterProvider).topicFilter;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.performanceTopicsTitle)),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isPerformanceApiAvailable,
            message: l10n.performanceSampleDataNotice,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MadeenSpace.pageMargin,
              MadeenSpace.md,
              MadeenSpace.pageMargin,
              0,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: MadeenChoicePills<TopicPerformanceFilter>(
                choices: [
                  MadeenChoice(
                    value: TopicPerformanceFilter.all,
                    label: l10n.performanceAllLabel,
                  ),
                  MadeenChoice(
                    value: TopicPerformanceFilter.strong,
                    label: l10n.performanceStrongLabel,
                  ),
                  MadeenChoice(
                    value: TopicPerformanceFilter.needsPractice,
                    label: l10n.performanceNeedsPracticeLabel,
                  ),
                ],
                selected: selectedFilter,
                onSelected: (value) => ref
                    .read(performanceFilterProvider.notifier)
                    .setTopicFilter(value),
              ),
            ),
          ),
          Expanded(
            child: AsyncListView<TopicPerformance>(
              value: topicsAsync,
              emptyMessage: l10n.performanceNoTopics,
              onRetry: () async {
                ref.invalidate(topicPerformanceProvider);
                await ref.read(topicPerformanceProvider.future);
              },
              itemBuilder: (context, topic) => Padding(
                padding: const EdgeInsets.only(bottom: MadeenSpace.xs),
                child: MadeenCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MadeenSpace.md,
                    vertical: MadeenSpace.xxs,
                  ),
                  child: TopicPerformanceTile(
                    topic: topic,
                    onAnalyzeWithAi: () => context.push(
                      AppRoutes.aiAnalysisTopic(topic.topicId),
                      extra: topic.topicName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
