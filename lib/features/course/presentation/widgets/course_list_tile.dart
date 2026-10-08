import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_enrollment.dart';
import 'course_format.dart';
import 'course_progress_bar.dart';

/// One row in the Course list — thumbnail placeholder, title,
/// description, lesson/duration metadata, and progress (once enrollment
/// has loaded). [enrollment] is `null` while its own fetch is still in
/// flight; progress is simply omitted rather than shown as a misleading
/// 0% in that window.
class CourseListTile extends StatelessWidget {
  const CourseListTile({
    super.key,
    required this.course,
    required this.enrollment,
    required this.onTap,
  });

  final Course course;
  final CourseEnrollment? enrollment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final metadata =
        '${l10n.courseLessonCount(course.totalLessons)} · '
        '${formatCourseDuration(course.totalDuration)}';
    final enrollment = this.enrollment;

    return Padding(
      padding: const EdgeInsets.only(bottom: MadeenSpace.sm),
      child: MadeenCard(
        onTap: onTap,
        semanticLabel: '${course.title}, ${course.description}, $metadata',
        padding: const EdgeInsets.all(MadeenSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The same deep-slate media frame as the lesson video area.
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: t.hero,
                borderRadius: BorderRadius.circular(MadeenRadius.base),
                border: Border.all(color: t.heroBorder),
              ),
              child: Icon(Icons.ondemand_video_outlined, color: t.onHeroMuted),
            ),
            const SizedBox(width: MadeenSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: MadeenType.headlineSm.copyWith(color: t.ink),
                  ),
                  const SizedBox(height: MadeenSpace.xxs),
                  Text(
                    course.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: MadeenType.bodySm.copyWith(color: t.inkSecondary),
                  ),
                  const SizedBox(height: MadeenSpace.xs),
                  Text(
                    metadata,
                    style: MadeenType.labelMd.copyWith(
                      color: t.inkSecondary,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (enrollment != null) ...[
                    const SizedBox(height: MadeenSpace.sm),
                    CourseProgressBar(
                      percent: course.completionPercent(enrollment),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
