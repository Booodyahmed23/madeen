import 'package:flutter/material.dart';

import '../../../core/theme/madeen_tokens.dart';

/// The solid primary trigger: full width, 48px, crisp 4px corners, never a
/// shadow (DESIGN.md "Primary Exam Trigger"). A [FilledButton] underneath,
/// styled by the MADEEN theme — so it stays a standard, accessible button.
class MadeenPrimaryButton extends StatelessWidget {
  const MadeenPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Leading icon. A trailing direction arrow is always shown and mirrors
  /// in RTL.
  final IconData? icon;

  /// Overrides for placing the trigger on a dark panel (e.g. the brass
  /// trigger on the hero); default is the theme's solid ink.
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return SizedBox(
      width: double.infinity,
      height: MadeenSize.buttonHeight,
      child: FilledButton(
        onPressed: onPressed,
        style: backgroundColor == null && foregroundColor == null
            ? null
            : FilledButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: foregroundColor,
              ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: MadeenSpace.xs),
            ],
            Flexible(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: MadeenSpace.xs),
            const Icon(Icons.arrow_forward, size: 18),
          ],
        ),
      ),
    );
  }
}

/// The ghost secondary action: 1px accent border, accent label
/// (DESIGN.md "Secondary Action"). An [OutlinedButton] underneath.
class MadeenSecondaryButton extends StatelessWidget {
  const MadeenSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(onPressed: onPressed, child: Text(label));
  }
}
