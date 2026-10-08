import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/course.dart';
import '../providers/course_providers.dart';
import '../widgets/course_format.dart';
import '../widgets/course_progress_bar.dart';
import '../widgets/lesson_list_tile.dart';

/// One course's sections and lessons, with this student's own progress —
/// reads [courseByIdProvider] (a lookup into [coursesProvider]'s
/// already-fetched list, never a second fetch) and
/// [courseEnrollmentProvider] (this student's own progress, fetched
/// independently of the course content itself).
class CourseDetailsScreen extends ConsumerWidget {
  const CourseDetailsScreen({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final coursesState = ref.watch(coursesProvider);
    final course = ref.watch(courseByIdProvider(courseId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.courseDetailsTitle)),
      body: coursesState.when(
        loading: () => const MadeenPageLoading(),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(coursesProvider),
        ),
        data: (_) => course == null
            ? MadeenPageMessage(message: l10n.courseNotFound)
            : _CourseDetailsBody(course: course),
      ),
    );
  }
}

class _CourseDetailsBody extends ConsumerWidget {
  const _CourseDetailsBody({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final enrollmentAsync = ref.watch(courseEnrollmentProvider(course.id));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        MadeenSpace.lg,
        MadeenSpace.pageMargin,
        MadeenSpace.xl,
      ),
      children: [
        Text(
          course.title,
          style: Theme.of(context).textTheme.headlineLarge!
              .copyWith(color: t.ink),
        ),
        const SizedBox(height: MadeenSpace.xs),
        Text(
          course.description,
          style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
        ),
        const SizedBox(height: MadeenSpace.sm),
        Text(
          '${l10n.courseLessonCount(course.totalLessons)} · '
          '${formatCourseDuration(course.totalDuration)}',
          style: MadeenType.labelMd.copyWith(
            color: t.inkSecondary,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: MadeenSpace.md),
        enrollmentAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => const SizedBox.shrink(),
          data: (enrollment) =>
              CourseProgressBar(percent: course.completionPercent(enrollment)),
        ),
        const SizedBox(height: MadeenSpace.lg),
        for (final section in [
          ...course.sections,
        ]..sort((a, b) => a.order.compareTo(b.order))) ...[
          MadeenCard(
            padding: const EdgeInsets.fromLTRB(
              MadeenSpace.md,
              MadeenSpace.md,
              MadeenSpace.md,
              MadeenSpace.xs,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  section.title,
                  style: MadeenType.headlineSm.copyWith(color: t.ink),
                ),
                const SizedBox(height: MadeenSpace.xxs),
                MadeenDividedList(
                  children: [
                    for (final lesson in [
                      ...section.lessons,
                    ]..sort((a, b) => a.order.compareTo(b.order)))
                      LessonListTile(
                        lesson: lesson,
                        isCompleted: enrollmentAsync.maybeWhen(
                          data: (enrollment) =>
                              enrollment.completedLessonIds.contains(lesson.id),
                          orElse: () => false,
                        ),
                        onTap: () => context.push(
                          AppRoutes.lessonDetail(course.id, lesson.id),
                          extra: course.title,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: MadeenSpace.md),
        ],
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final message = error is AppFailure
        ? localizedFailureMessage(l10n, error as AppFailure)
        : l10n.courseGenericError;

    return MadeenPageMessage(
      message: message,
      isError: true,
      actionLabel: l10n.courseRetryButton,
      onAction: onRetry,
    );
  }
}
