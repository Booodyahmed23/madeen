import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/theme/app_theme.dart';
import 'package:mobile/features/performance/domain/entities/trend_day.dart';
import 'package:mobile/features/performance/presentation/widgets/accuracy_trend_chart.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

final week = [
  TrendDay(date: DateTime(2026, 10, 3), correct: 0, total: 0),
  TrendDay(
    date: DateTime(2026, 10, 4),
    correct: 2,
    total: 5,
    accuracyPercent: 40,
  ),
  TrendDay(date: DateTime(2026, 10, 5), correct: 0, total: 0),
  TrendDay(date: DateTime(2026, 10, 6), correct: 0, total: 0),
  TrendDay(
    date: DateTime(2026, 10, 7),
    correct: 0,
    total: 2,
    accuracyPercent: 0,
  ),
  TrendDay(
    date: DateTime(2026, 10, 8),
    correct: 2,
    total: 4,
    accuracyPercent: 50,
  ),
  TrendDay(
    date: DateTime(2026, 10, 9),
    correct: 1,
    total: 1,
    accuracyPercent: 100,
  ),
];

Widget chartApp(
  List<TrendDay> days, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
}) => MaterialApp(
  theme: theme ?? AppTheme.madeenLight,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: AccuracyTrendChart(days: days),
    ),
  ),
);

void main() {
  testWidgets('a headline, one labelled column per day, and only the '
      'latest value written on the chart', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(chartApp(week));

    // 5 of 12 answers correct over the week.
    expect(find.text('42% across 12 answers'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('50%'), findsNothing);
    expect(find.text('Fri'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Oct 4: 40% \(2 of 5\)')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp(r'Oct 5: no answers')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a week without answers says so instead of drawing', (
    tester,
  ) async {
    await tester.pumpWidget(
      chartApp([
        for (final day in week) TrendDay(date: day.date, correct: 0, total: 0),
      ]),
    );

    expect(find.text('No answers in the last 7 days.'), findsOneWidget);
  });
}
