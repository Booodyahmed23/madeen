import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/async_list_view.dart';
import '../../domain/entities/unit.dart';
import '../providers/curriculum_providers.dart';
import '../widgets/curriculum_app_bar_title.dart';
import '../widgets/curriculum_list_tile.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/sample_data_banner.dart';

class UnitsScreen extends ConsumerWidget {
  const UnitsScreen({super.key, required this.partId, this.partName});

  final String partId;
  final String? partName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final units = ref.watch(unitsProvider(partId));

    return Scaffold(
      appBar: AppBar(
        title: CurriculumAppBarTitle(
          label: l10n.curriculumUnitsLabel,
          parentName: partName,
        ),
      ),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isCurriculumApiAvailable,
            message: l10n.curriculumSampleDataNotice,
          ),
          Expanded(
            child: AsyncListView<Unit>(
              value: units,
              emptyMessage: l10n.curriculumNoUnits,
              onRetry: () async => ref.invalidate(unitsProvider(partId)),
              itemBuilder: (context, unit) => CurriculumListTile(
                title: unit.name,
                subtitle: unit.description,
                onTap: () => context.push(
                  AppRoutes.curriculumSubUnits(unit.id),
                  extra: unit.name,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
