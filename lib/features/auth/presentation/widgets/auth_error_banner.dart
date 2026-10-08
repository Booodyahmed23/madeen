import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

/// Inline error shown above an auth form. Takes an already-localized
/// [message] (see `localizedFailureMessage`) — never a raw `AppFailure`,
/// whose `message` is English/backend text. A live region, so screen
/// readers announce the error when it appears after a submit.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) return const SizedBox.shrink();

    final t = MadeenTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: MadeenSpace.md),
      child: Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(MadeenSpace.sm),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.circular(MadeenRadius.base),
            border: Border.all(color: t.error),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: t.error, size: 20),
              const SizedBox(width: MadeenSpace.xs),
              Expanded(
                child: Text(
                  message,
                  style: MadeenType.bodySm.copyWith(color: t.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
