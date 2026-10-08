import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../../../shared/widgets/async_list_view.dart';
import '../../domain/entities/topic.dart';
import '../providers/curriculum_providers.dart';
import '../widgets/curriculum_app_bar_title.dart';
import '../widgets/curriculum_list_tile.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/sample_data_banner.dart';

class TopicsScreen extends ConsumerWidget {
  const TopicsScreen({
    super.key,
    required this.programId,
    required this.subUnitId,
    this.subUnitName,
  });

  final String programId;
  final String subUnitId;
  final String? subUnitName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final topics = ref.watch(
      topicsProvider((programId: programId, subUnitId: subUnitId)),
    );

    return Scaffold(
      appBar: AppBar(
        title: CurriculumAppBarTitle(
          label: l10n.curriculumTopicsLabel,
          parentName: subUnitName,
        ),
      ),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isCurriculumApiAvailable,
            message: l10n.curriculumSampleDataNotice,
          ),
          Expanded(
            child: AsyncListView<Topic>(
              value: topics,
              emptyMessage: l10n.curriculumNoTopics,
              onRetry: () async =>
                  ref.invalidate(programTreeProvider(programId)),
              itemBuilder: (context, topic) => CurriculumListTile(
                title: topic.name,
                subtitle: topic.hasQuestions
                    ? topic.description
                    : l10n.curriculumTopicNoQuestions,
                leading: Icon(
                  Icons.article_outlined,
                  color: MadeenTokens.of(context).accentText,
                ),
                // Leaf node: opens Study Session setup. A topic with no
                // published questions has nothing to study, so it's
                // disabled rather than leading to an empty session.
                onTap: topic.hasQuestions
                    ? () => context.push(
                        AppRoutes.curriculumTopicDetail(topic.id),
                        extra: topic.name,
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
