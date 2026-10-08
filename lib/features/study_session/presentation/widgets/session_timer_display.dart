import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

/// Renders a [Duration] as count-up `mm:ss` (`h:mm:ss` past an hour) — this
/// is a *stopwatch*, not the Exam Simulation's countdown, so it only ever
/// counts up and never turns red/warns near a limit.
class SessionTimerDisplay extends StatelessWidget {
  const SessionTimerDisplay({
    super.key,
    required this.elapsed,
    this.isPaused = false,
  });

  final Duration elapsed;
  final bool isPaused;

  static String format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPaused ? Icons.pause_circle_outline : Icons.timer_outlined,
          size: 18,
          color: isPaused ? t.accentText : t.inkSecondary,
        ),
        const SizedBox(width: MadeenSpace.xxs),
        // Tabular figures: the clock never jitters as digits change.
        Text(
          format(elapsed),
          style: MadeenType.metricMd.copyWith(color: t.ink, fontSize: 17),
        ),
      ],
    );
  }
}
