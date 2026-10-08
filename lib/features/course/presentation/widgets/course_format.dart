/// `h:mm:ss` once an hour is involved, `m:ss` otherwise — a pure
/// digit-and-colon clock format with no English words to localize,
/// mirroring `performance_format.dart`'s own `formatPerformanceDuration`
/// exactly (same reasoning: duplicated here rather than imported so this
/// feature stays independent of Performance).
String formatLessonDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// Same format, for a whole course's total duration across every lesson.
String formatCourseDuration(Duration d) => formatLessonDuration(d);
