import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/async_list_view.dart';
import '../../../../shared/widgets/sample_data_banner.dart';
import '../../domain/entities/course.dart';
import '../providers/course_providers.dart';
import '../widgets/course_list_tile.dart';

/// Every available course — mock-backed (see COURSE_API_REQUIREMENTS.md).
/// Deliberately shows no "locked"/"premium" state on any course: access
/// control is an Entitlement concern this project has not implemented
/// anywhere (mobile or backend) — see `Course`'s own doc comment. Every
/// listed course is simply browsable.
class CoursesScreen extends ConsumerWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final courses = ref.watch(coursesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.courseListTitle)),
      body: Column(
        children: [
          SampleDataBanner(
            isSampleData: !AppConfig.isCourseApiAvailable,
            message: l10n.courseSampleDataNotice,
          ),
          Expanded(
            child: AsyncListView<Course>(
              value: courses,
              emptyMessage: l10n.courseListEmpty,
              onRetry: () async => ref.invalidate(coursesProvider),
              itemBuilder: (context, course) => Consumer(
                builder: (context, ref, _) {
                  final enrollment = ref
                      .watch(courseEnrollmentProvider(course.id))
                      .value;
                  return CourseListTile(
                    course: course,
                    enrollment: enrollment,
                    onTap: () => context.push(
                      AppRoutes.courseDetail(course.id),
                      extra: course.title,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
