import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Direction + alignment for free-text *content* (a question, an answer, a
/// notification body) that may be in a different script from the UI — e.g.
/// English exam content while the app is in Arabic. The text is laid out
/// in its own direction, so punctuation lands on the correct side, yet
/// stays aligned to the UI's start edge like everything around it.
({TextDirection direction, TextAlign align}) contentTextLayout(
  BuildContext context,
  String text,
) {
  final isRtlUi = Directionality.of(context) == TextDirection.rtl;
  return (
    direction: Bidi.detectRtlDirectionality(text)
        ? TextDirection.rtl
        : TextDirection.ltr,
    align: isRtlUi ? TextAlign.right : TextAlign.left,
  );
}

/// A [Text] for free-text content, laid out per [contentTextLayout].
class MadeenContentText extends StatelessWidget {
  const MadeenContentText(this.text, {super.key, this.style});

  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final layout = contentTextLayout(context, text);
    return Text(
      text,
      style: style,
      textDirection: layout.direction,
      textAlign: layout.align,
    );
  }
}
