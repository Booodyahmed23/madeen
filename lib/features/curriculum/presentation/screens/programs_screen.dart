import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../../../shared/widgets/async_list_view.dart';
import '../../domain/entities/program.dart';
import '../providers/curriculum_providers.dart';
import '../widgets/curriculum_list_tile.dart';
import '../../../../core/config/app_config.dart';
import '../../../../shared/widgets/sample_data_banner.dart';

class ProgramsScreen extends ConsumerWidget {
  const ProgramsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final programs = ref.watch(programsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.curriculumProgramsTitle)),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isCurriculumApiAvailable,
            message: l10n.curriculumSampleDataNotice,
          ),
          Expanded(
            child: AsyncListView<Program>(
              value: programs,
              emptyMessage: l10n.curriculumNoPrograms,
              onRetry: () async => ref.invalidate(programsProvider),
              itemBuilder: (context, program) => CurriculumListTile(
                title: program.name,
                subtitle: program.description,
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MadeenTokens.of(context).hero,
                    borderRadius: BorderRadius.circular(MadeenRadius.base),
                  ),
                  child: Text(
                    program.name.isNotEmpty
                        ? program.name.characters.first
                        : '?',
                    style: MadeenType.headlineMd.copyWith(
                      color: MadeenTokens.of(context).heroAccent,
                    ),
                  ),
                ),
                onTap: () => context.push(
                  AppRoutes.curriculumParts(program.id),
                  extra: program.name,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
