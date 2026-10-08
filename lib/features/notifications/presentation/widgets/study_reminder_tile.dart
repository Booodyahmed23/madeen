import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/reminder_repeat.dart';
import '../../domain/entities/study_reminder.dart';
import 'study_reminder_format.dart';

/// One row on the Study Reminders list — title, time, repeat pattern (and
/// the specific days for [ReminderRepeat.custom]), plus an enable/disable
/// switch and a delete action. Tapping the row (outside the switch) opens
/// the editor — same "row taps to edit, trailing control is its own
/// affordance" split [StudyReminder]'s own screen brief describes.
class StudyReminderTile extends StatelessWidget {
  const StudyReminderTile({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  final StudyReminder reminder;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final time = formatReminderTime(context, reminder.hour, reminder.minute);
    final repeatLabel = reminderRepeatLabel(l10n, reminder.repeat);
    final daysLabel = reminder.repeat == ReminderRepeat.custom
        ? weekdaysSummary(l10n, reminder.customDays)
        : null;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        reminder.title,
        style: MadeenType.bodyMd.copyWith(
          color: reminder.enabled ? t.ink : t.inkTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        daysLabel == null || daysLabel.isEmpty
            ? '$time · $repeatLabel'
            : '$time · $repeatLabel · $daysLabel',
        style: MadeenType.bodySm.copyWith(
          color: t.inkSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: reminder.title,
            child: Switch(value: reminder.enabled, onChanged: onToggle),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: t.inkSecondary),
            tooltip: l10n.studyRemindersDeleteAction,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
