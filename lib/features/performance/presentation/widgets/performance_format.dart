import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// `h:mm:ss` once an hour is involved, `m:ss` otherwise — handles both a
/// 60-second Study Session question and a multi-hour Exam Simulation
/// attempt without a separate formatter per screen. Mirrors
/// exam_results_screen.dart's own `_formatDuration` exactly, duplicated
/// here rather than imported so this feature has no compile-time dependency
/// on exam_simulation's presentation layer (see this feature's README on
/// why analytics stays independent of the features it summarizes).
String formatPerformanceDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// Locale-aware short date (e.g. "Sep 16" in English, the Arabic
/// equivalent in `ar`) for Attempt History rows — `DateFormat` picks up its
/// locale data from the same `flutter_localizations` delegates already
/// registered in app/app.dart, so no separate initialization is needed.
String formatPerformanceDate(BuildContext context, DateTime date) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.MMMd(locale).format(date);
}
