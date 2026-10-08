import 'package:flutter/material.dart';

import '../../../../shared/widgets/madeen/madeen.dart';

/// Renders a remaining-seconds count as `mm:ss` (`h:mm:ss` past an hour) —
/// this is a countdown, the opposite of Study Session's count-up
/// `SessionTimerDisplay`. Turns to the theme's error color under the last
/// five minutes as a purely visual urgency cue — the actual timeout
/// behavior lives in ExamNotifier, not here.
class ExamCountdownDisplay extends StatelessWidget {
  const ExamCountdownDisplay({super.key, required this.remaining});

  final Duration remaining;

  static const _urgentThreshold = Duration(minutes: 5);

  static String format(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final isUrgent = remaining <= _urgentThreshold;
    // DESIGN.md: time-budget warnings use terracotta attention, not error.
    final color = isUrgent ? t.attention : t.ink;

    return Semantics(
      liveRegion: true,
      label: format(remaining),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: color),
          const SizedBox(width: MadeenSpace.xxs),
          // Tabular figures: the countdown never jitters.
          Text(
            format(remaining),
            style: MadeenType.metricMd.copyWith(
              color: color,
              fontSize: 17,
              fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
