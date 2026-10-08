import 'package:flutter/material.dart';

import '../../../../l10n/generated/app_localizations.dart';

/// The single "Submit Simulation?" confirmation, shared by every place that
/// can submit (the Exam Review screen and the question navigator) so the
/// wording and the unanswered-count warning can never drift apart.
/// Resolves to `true` only when the student explicitly confirms.
Future<bool> confirmExamSubmission(
  BuildContext context, {
  required int unansweredCount,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.examSubmitConfirmTitle),
      content: Text(
        unansweredCount > 0
            ? l10n.examSubmitConfirmUnansweredWarning(unansweredCount)
            : l10n.examSubmitConfirmAllAnswered,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.examSubmitConfirmCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.examSubmitConfirmConfirm),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
