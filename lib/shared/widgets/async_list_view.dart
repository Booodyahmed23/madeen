import 'package:flutter/material.dart';

import '../../core/error/failure_messages.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/app_failure.dart';
import '../../l10n/generated/app_localizations.dart';
import 'madeen/madeen.dart';

/// Renders an `AsyncValue<List<T>>` with consistent loading/empty/error/data
/// states — every curriculum screen needs exactly these four states
/// (ARCHITECTURE.md Phase 3 UX requirements), so this is the one place that
/// logic lives rather than five near-identical copies.
///
/// Cross-feature and presentation-only, hence `shared/widgets/` rather than
/// living inside the curriculum feature.
class AsyncListView<T> extends StatelessWidget {
  const AsyncListView({
    super.key,
    required this.value,
    required this.itemBuilder,
    required this.onRetry,
    this.emptyMessage,
  });

  final AsyncValue<List<T>> value;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Future<void> Function() onRetry;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: MadeenLoadingState()),
      error: (error, _) => _ErrorView(failure: error, onRetry: onRetry),
      data: (items) {
        if (items.isEmpty) {
          return _EmptyView(message: emptyMessage, onRetry: onRetry);
        }
        return RefreshIndicator(
          onRefresh: onRetry,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              MadeenSpace.pageMargin,
              MadeenSpace.md,
              MadeenSpace.pageMargin,
              MadeenSpace.xl,
            ),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: items.length,
            itemBuilder: (context, index) => itemBuilder(context, items[index]),
          ),
        );
      },
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.failure, required this.onRetry});

  final Object failure;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final message = failure is AppFailure
        ? localizedFailureMessage(l10n, failure as AppFailure)
        : l10n.curriculumGenericError;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MadeenSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 32, color: t.error),
            const SizedBox(height: MadeenSpace.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: MadeenType.bodyMd.copyWith(color: t.ink),
            ),
            const SizedBox(height: MadeenSpace.md),
            MadeenSecondaryButton(
              label: l10n.curriculumRetry,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.message, required this.onRetry});

  final String? message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    return RefreshIndicator(
      onRefresh: onRetry,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(MadeenSpace.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined, size: 32, color: t.inkTertiary),
                    const SizedBox(height: MadeenSpace.sm),
                    Text(
                      message ?? l10n.curriculumEmpty,
                      textAlign: TextAlign.center,
                      style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
