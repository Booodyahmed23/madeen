import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';
import '../../../core/theme/madeen_typography.dart';
import 'madeen_buttons.dart';

/// In-panel loading state — a small, quiet accent spinner (never a
/// full-screen takeover for one section).
class MadeenLoadingState extends StatelessWidget {
  const MadeenLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: MadeenSpace.lg),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

/// In-panel error state: the section's own localized message plus a ghost
/// retry button. Messages/labels are passed in so each section reuses its
/// feature's existing strings.
class MadeenErrorState extends StatelessWidget {
  const MadeenErrorState({
    super.key,
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, size: 18, color: t.error),
            const SizedBox(width: MadeenSpace.xs),
            Expanded(
              child: Text(
                message,
                style: MadeenType.bodySm.copyWith(color: t.error),
              ),
            ),
          ],
        ),
        const SizedBox(height: MadeenSpace.sm),
        MadeenSecondaryButton(label: retryLabel, onPressed: onRetry),
      ],
    );
  }
}

/// In-panel empty state: a short secondary-ink sentence, optionally with a
/// follow-up action.
class MadeenEmptyState extends StatelessWidget {
  const MadeenEmptyState({super.key, required this.message, this.action});

  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final action = this.action;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message, style: MadeenType.bodyMd.copyWith(color: t.inkSecondary)),
        if (action != null) ...[
          const SizedBox(height: MadeenSpace.xxs),
          action,
        ],
      ],
    );
  }
}

/// Whole-page loading — a centered quiet spinner (body of a screen whose
/// primary content is still loading).
class MadeenPageLoading extends StatelessWidget {
  const MadeenPageLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: MadeenLoadingState());
  }
}

/// Whole-page message — a centered icon, sentence and optional action:
/// a screen-level error (with retry) or empty state. [isError] tints the
/// icon with the error color; otherwise it is a quiet tertiary ink.
class MadeenPageMessage extends StatelessWidget {
  const MadeenPageMessage({
    super.key,
    required this.message,
    this.icon,
    this.isError = false,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final IconData? icon;
  final bool isError;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final actionLabel = this.actionLabel;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(MadeenSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon ?? (isError ? Icons.error_outline : Icons.inbox_outlined),
              size: 32,
              color: isError ? t.error : t.inkTertiary,
            ),
            const SizedBox(height: MadeenSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MadeenType.bodyMd.copyWith(
                color: isError ? t.ink : t.inkSecondary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: MadeenSpace.md),
              MadeenSecondaryButton(label: actionLabel, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}
