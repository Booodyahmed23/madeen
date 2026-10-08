import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/async_list_view.dart';
import '../../domain/entities/part.dart';
import '../providers/curriculum_providers.dart';
import '../widgets/curriculum_app_bar_title.dart';
import '../widgets/curriculum_list_tile.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/sample_data_banner.dart';

class PartsScreen extends ConsumerWidget {
  const PartsScreen({super.key, required this.programId, this.programName});

  final String programId;
  final String? programName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final parts = ref.watch(partsProvider(programId));

    return Scaffold(
      appBar: AppBar(
        title: CurriculumAppBarTitle(
          label: l10n.curriculumPartsLabel,
          parentName: programName,
        ),
      ),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isCurriculumApiAvailable,
            message: l10n.curriculumSampleDataNotice,
          ),
          Expanded(
            child: AsyncListView<Part>(
              value: parts,
              emptyMessage: l10n.curriculumNoParts,
              onRetry: () async => ref.invalidate(partsProvider(programId)),
              itemBuilder: (context, part) => CurriculumListTile(
                title: part.name,
                subtitle: part.description,
                onTap: () => context.push(
                  AppRoutes.curriculumUnits(part.id),
                  extra: part.name,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
