import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/async_list_view.dart';
import '../../domain/entities/sub_unit.dart';
import '../providers/curriculum_providers.dart';
import '../widgets/curriculum_app_bar_title.dart';
import '../widgets/curriculum_list_tile.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/sample_data_banner.dart';

class SubUnitsScreen extends ConsumerWidget {
  const SubUnitsScreen({super.key, required this.unitId, this.unitName});

  final String unitId;
  final String? unitName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final subUnits = ref.watch(subUnitsProvider(unitId));

    return Scaffold(
      appBar: AppBar(
        title: CurriculumAppBarTitle(
          label: l10n.curriculumSubUnitsLabel,
          parentName: unitName,
        ),
      ),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isCurriculumApiAvailable,
            message: l10n.curriculumSampleDataNotice,
          ),
          Expanded(
            child: AsyncListView<SubUnit>(
              value: subUnits,
              emptyMessage: l10n.curriculumNoSubUnits,
              onRetry: () async => ref.invalidate(subUnitsProvider(unitId)),
              itemBuilder: (context, subUnit) => CurriculumListTile(
                title: subUnit.name,
                subtitle: subUnit.description,
                onTap: () => context.push(
                  AppRoutes.curriculumTopics(subUnit.id),
                  extra: subUnit.name,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
