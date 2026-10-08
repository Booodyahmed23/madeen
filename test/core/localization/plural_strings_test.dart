import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ar = lookupAppLocalizations(const Locale('ar'));

  group('English counts agree with their noun', () {
    test('singular', () {
      expect(
        en.examSubmitConfirmUnansweredWarning(1),
        'You still have 1 unanswered question.',
      );
      expect(en.courseLessonCount(1), '1 lesson');
      expect(en.examReviewQuestionsCount(1), '1 Question');
      expect(en.performanceAttemptQuestionsCount(1), '1 Question');
      expect(en.notificationsUnreadBadgeSemantic(1), '1 unread notification');
      expect(
        en.aiAnalysisBasedOnAttempts(1),
        'Based on your most recent attempt',
      );
    });

    test('plural', () {
      expect(
        en.examSubmitConfirmUnansweredWarning(8),
        'You still have 8 unanswered questions.',
      );
      expect(en.courseLessonCount(4), '4 lessons');
      expect(en.performanceAttemptQuestionsCount(20), '20 Questions');
    });
  });

  group('Arabic counts use the grammatical number form', () {
    test('1 and 2 use the singular and dual nouns', () {
      expect(ar.courseLessonCount(1), 'درس واحد');
      expect(ar.courseLessonCount(2), 'درسان');
      expect(ar.examReviewQuestionsCount(2), 'سؤالان');
      expect(
        ar.examSubmitConfirmUnansweredWarning(1),
        'لا يزال لديك سؤال واحد بدون إجابة.',
      );
    });

    test('3–10 take the plural noun', () {
      expect(ar.courseLessonCount(4), '4 دروس');
      expect(ar.performanceAttemptQuestionsCount(10), '10 أسئلة');
      expect(ar.notificationsUnreadBadgeSemantic(3), '3 إشعارات غير مقروءة');
    });

    test('11–99 take the singular accusative noun', () {
      // Exam Simulation's 20/50/80 question counts.
      expect(ar.performanceAttemptQuestionsCount(20), '20 سؤالًا');
      expect(ar.examReviewQuestionsCount(80), '80 سؤالًا');
      expect(ar.aiAnalysisBasedOnAttempts(14), 'استنادًا إلى آخر 14 محاولة');
    });

    test('100 takes the singular noun', () {
      expect(ar.performanceAttemptQuestionsCount(100), '100 سؤال');
    });
  });
}
