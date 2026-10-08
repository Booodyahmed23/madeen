import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/madeen/madeen.dart';

Future<Text> _render(
  WidgetTester tester,
  String content,
  TextDirection ui,
) async {
  await tester.pumpWidget(
    Directionality(textDirection: ui, child: MadeenContentText(content)),
  );
  return tester.widget<Text>(find.byType(Text));
}

void main() {
  testWidgets(
    'English content in the Arabic UI keeps LTR punctuation, aligned to the '
    'RTL start edge',
    (tester) async {
      final text = await _render(
        tester,
        'Sample exam question 1.',
        TextDirection.rtl,
      );
      expect(text.textDirection, TextDirection.ltr);
      expect(text.textAlign, TextAlign.right);
    },
  );

  testWidgets('Arabic content in the Arabic UI is plain RTL', (tester) async {
    final text = await _render(
      tester,
      'ما هو تحليل الانحرافات؟',
      TextDirection.rtl,
    );
    expect(text.textDirection, TextDirection.rtl);
    expect(text.textAlign, TextAlign.right);
  });

  testWidgets('English content in the English UI is plain LTR', (tester) async {
    final text = await _render(tester, 'What is variance?', TextDirection.ltr);
    expect(text.textDirection, TextDirection.ltr);
    expect(text.textAlign, TextAlign.left);
  });
}
