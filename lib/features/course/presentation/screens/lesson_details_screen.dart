import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../data/repositories/course_repository_impl.dart';
import '../../domain/entities/lesson.dart';
import '../providers/course_providers.dart';
import '../widgets/course_format.dart';
import '../widgets/video_placeholder.dart';

/// One lesson's detail — video placeholder (see that widget's own doc
/// comment on why it's never a real player), description, duration, a
/// mark-as-completed toggle, and previous/next navigation across
/// [Course.lessonsInOrder]. Records "last accessed" once per screen open
/// — never on every rebuild — mirroring
/// `NotificationDetailsPage`'s own "mark as read once" guard.
class LessonDetailsScreen extends ConsumerStatefulWidget {
  const LessonDetailsScreen({
    super.key,
    required this.courseId,
    required this.lessonId,
  });

  final String courseId;
  final String lessonId;

  @override
  ConsumerState<LessonDetailsScreen> createState() =>
      _LessonDetailsScreenState();
}

class _LessonDetailsScreenState extends ConsumerState<LessonDetailsScreen> {
  bool _recordedOpen = false;

  void _maybeRecordOpen() {
    if (_recordedOpen) return;
    _recordedOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(courseRepositoryProvider)
          .setLastAccessedLesson(
            courseId: widget.courseId,
            lessonId: widget.lessonId,
          );
      ref.invalidate(courseEnrollmentProvider(widget.courseId));
    });
  }

  Future<void> _toggleCompleted(bool completed) async {
    await ref
        .read(courseRepositoryProvider)
        .setLessonCompleted(
          courseId: widget.courseId,
          lessonId: widget.lessonId,
          completed: completed,
        );
    ref.invalidate(courseEnrollmentProvider(widget.courseId));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final coursesState = ref.watch(coursesProvider);
    final course = ref.watch(courseByIdProvider(widget.courseId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.courseLessonDetailsTitle)),
      body: coursesState.when(
        loading: () => const MadeenPageLoading(),
        error: (error, _) => _ErrorView(
          error: error,
          onRetry: () => ref.invalidate(coursesProvider),
        ),
        data: (_) {
          if (course == null) {
            return MadeenPageMessage(message: l10n.courseNotFound);
          }

          final lessons = course.lessonsInOrder;
          final index = lessons.indexWhere((l) => l.id == widget.lessonId);
          if (index == -1) {
            return MadeenPageMessage(message: l10n.courseLessonNotFound);
          }

          _maybeRecordOpen();
          final lesson = lessons[index];
          final previous = index > 0 ? lessons[index - 1] : null;
          final next = index < lessons.length - 1 ? lessons[index + 1] : null;

          return _LessonBody(
            courseId: widget.courseId,
            courseTitle: course.title,
            lesson: lesson,
            previous: previous,
            next: next,
            onToggleCompleted: _toggleCompleted,
          );
        },
      ),
    );
  }
}

class _LessonBody extends ConsumerWidget {
  const _LessonBody({
    required this.courseId,
    required this.courseTitle,
    required this.lesson,
    required this.previous,
    required this.next,
    required this.onToggleCompleted,
  });

  final String courseId;
  final String courseTitle;
  final Lesson lesson;
  final Lesson? previous;
  final Lesson? next;
  final Future<void> Function(bool completed) onToggleCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final enrollmentAsync = ref.watch(courseEnrollmentProvider(courseId));
    final isCompleted = enrollmentAsync.maybeWhen(
      data: (e) => e.completedLessonIds.contains(lesson.id),
      orElse: () => false,
    );

    final t = MadeenTokens.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.pageMargin,
        MadeenSpace.lg,
        MadeenSpace.pageMargin,
        MadeenSpace.xl,
      ),
      children: [
        const VideoPlaceholder(),
        const SizedBox(height: MadeenSpace.lg),
        Text(
          lesson.title,
          style: Theme.of(context).textTheme.headlineLarge!
              .copyWith(color: t.ink),
        ),
        const SizedBox(height: MadeenSpace.xxs),
        Text(
          formatLessonDuration(lesson.duration),
          style: MadeenType.labelMd.copyWith(
            color: t.inkSecondary,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: MadeenSpace.md),
        Text(
          lesson.description,
          style: MadeenType.bodyMd.copyWith(color: t.ink),
        ),
        const SizedBox(height: MadeenSpace.lg),
        MadeenCard(
          padding: const EdgeInsets.symmetric(horizontal: MadeenSpace.md),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.courseMarkAsCompleted),
            value: isCompleted,
            onChanged: onToggleCompleted,
          ),
        ),
        const SizedBox(height: MadeenSpace.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: previous == null
                    ? null
                    : () => context.pushReplacement(
                        AppRoutes.lessonDetail(courseId, previous!.id),
                        extra: courseTitle,
                      ),
                icon: const Icon(Icons.chevron_left),
                label: Text(l10n.courseLessonPrevious),
              ),
            ),
            const SizedBox(width: MadeenSpace.sm),
            Expanded(
              child: FilledButton.icon(
                onPressed: next == null
                    ? null
                    : () => context.pushReplacement(
                        AppRoutes.lessonDetail(courseId, next!.id),
                        extra: courseTitle,
                      ),
                icon: const Icon(Icons.chevron_right),
                iconAlignment: IconAlignment.end,
                label: Text(l10n.courseLessonNext),
              ),
            ),
          ],
        ),
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
