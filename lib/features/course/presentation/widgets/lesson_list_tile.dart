import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/lesson.dart';
import 'course_format.dart';

/// One lesson row on Course Details — completion is shown as a check icon
/// **and** a filled/outlined distinction **and** this label, never by
/// color alone, matching every other completion/priority indicator in
/// this app (see Notifications' own priority-badge doc comment for the
/// same posture).
class LessonListTile extends StatelessWidget {
  const LessonListTile({
    super.key,
    required this.lesson,
    required this.isCompleted,
    required this.onTap,
  });

  final Lesson lesson;
  final bool isCompleted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final completionLabel = isCompleted
        ? l10n.courseLessonCompleted
        : l10n.courseLessonNotCompleted;

    return Semantics(
      button: true,
      label: '${lesson.title}, $completionLabel',
      excludeSemantics: true,
      child: ListTile(
        onTap: onTap,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          isCompleted ? Icons.check_circle : Icons.play_circle_outline,
          color: isCompleted ? t.success : t.inkSecondary,
        ),
        title: Text(lesson.title),
        subtitle: Text(formatLessonDuration(lesson.duration)),
        trailing: Icon(Icons.chevron_right, color: t.inkTertiary),
      ),
    );
  }
}
