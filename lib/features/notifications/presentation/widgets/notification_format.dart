import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../shared/widgets/madeen/madeen_content_text.dart';

import '../../../../l10n/generated/app_localizations.dart';
import '../../domain/entities/notification_type.dart';

/// Locale-aware date + time (e.g. "Sep 25, 8:00 AM" in English) for a
/// notification's `createdAt` — same `DateFormat` pattern as
/// `performance_format.dart`'s own `formatPerformanceDate`.
String formatNotificationTimestamp(BuildContext context, DateTime dateTime) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.MMMd(locale).add_jm().format(dateTime);
}

/// Notification title/body are free text that may be in a different script
/// from the UI (e.g. English content while the app is in Arabic). The text
/// is laid out in its own direction, so punctuation lands on the correct
/// side, yet stays aligned to the UI's start edge like the rest of the row.
({TextDirection direction, TextAlign align}) notificationTextLayout(
  BuildContext context,
  String text,
) => contentTextLayout(context, text);

/// The icon shown on a notification's list tile / details page — one per
/// [NotificationType], never inferred from free-text title/body.
IconData notificationTypeIcon(NotificationType type) => switch (type) {
  NotificationType.studyReminder => Icons.menu_book_outlined,
  NotificationType.examReminder => Icons.timer_outlined,
  NotificationType.performanceUpdate => Icons.insights_outlined,
  NotificationType.aiRecommendation => Icons.auto_awesome_outlined,
  NotificationType.achievement => Icons.emoji_events_outlined,
  NotificationType.system => Icons.info_outline,
};

/// The localized label for [type] — used both as on-screen text (Details'
/// "Type" row) and as part of each list tile's semantic label, never a raw
/// enum name.
String notificationTypeLabel(
  AppLocalizations l10n,
  NotificationType type,
) => switch (type) {
  NotificationType.studyReminder => l10n.notificationTypeStudyReminder,
  NotificationType.examReminder => l10n.notificationTypeExamReminder,
  NotificationType.performanceUpdate => l10n.notificationTypePerformanceUpdate,
  NotificationType.aiRecommendation => l10n.notificationTypeAiRecommendation,
  NotificationType.achievement => l10n.notificationTypeAchievement,
  NotificationType.system => l10n.notificationTypeSystem,
};
