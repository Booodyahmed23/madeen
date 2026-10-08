import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/notifications/domain/entities/notification_action.dart';
import 'package:mobile/features/notifications/presentation/navigation/notification_action_resolver.dart';

void main() {
  group('NotificationActionResolver.resolve', () {
    test(
      'openStudySessionSetup resolves to the topic route when targetId is set',
      () {
        const action = NotificationAction(
          type: NotificationActionType.openStudySessionSetup,
          targetId: 'topic-1',
        );
        expect(
          NotificationActionResolver.resolve(action),
          AppRoutes.curriculumTopicDetail('topic-1'),
        );
      },
    );

    test('openStudySessionSetup resolves to null without a targetId', () {
      const action = NotificationAction(
        type: NotificationActionType.openStudySessionSetup,
      );
      expect(NotificationActionResolver.resolve(action), isNull);
    });

    test('openExamSetup never needs a targetId', () {
      const action = NotificationAction(
        type: NotificationActionType.openExamSetup,
      );
      expect(NotificationActionResolver.resolve(action), AppRoutes.examSetup);
    });

    test('openPerformanceOverview never needs a targetId', () {
      const action = NotificationAction(
        type: NotificationActionType.openPerformanceOverview,
      );
      expect(
        NotificationActionResolver.resolve(action),
        AppRoutes.performanceOverview,
      );
    });

    test(
      'openTopicPerformance resolves to the topic list, ignoring targetId',
      () {
        const action = NotificationAction(
          type: NotificationActionType.openTopicPerformance,
          targetId: 'topic-1',
        );
        expect(
          NotificationActionResolver.resolve(action),
          AppRoutes.performanceTopics,
        );
      },
    );

    test(
      'openAttemptDetails resolves to that attempt when targetId is set',
      () {
        const action = NotificationAction(
          type: NotificationActionType.openAttemptDetails,
          targetId: 'attempt-1',
        );
        expect(
          NotificationActionResolver.resolve(action),
          AppRoutes.performanceAttemptDetail('attempt-1'),
        );
      },
    );

    test('openAttemptDetails resolves to null without a targetId', () {
      const action = NotificationAction(
        type: NotificationActionType.openAttemptDetails,
      );
      expect(NotificationActionResolver.resolve(action), isNull);
    });

    test('openAiAnalysisOverview never needs a targetId', () {
      const action = NotificationAction(
        type: NotificationActionType.openAiAnalysisOverview,
      );
      expect(
        NotificationActionResolver.resolve(action),
        AppRoutes.aiAnalysisOverview,
      );
    });

    test('openAiAnalysisTopic resolves to that topic when targetId is set', () {
      const action = NotificationAction(
        type: NotificationActionType.openAiAnalysisTopic,
        targetId: 'topic-1',
      );
      expect(
        NotificationActionResolver.resolve(action),
        AppRoutes.aiAnalysisTopic('topic-1'),
      );
    });

    test(
      'openAiAnalysisAttempt resolves to that attempt when targetId is set',
      () {
        const action = NotificationAction(
          type: NotificationActionType.openAiAnalysisAttempt,
          targetId: 'attempt-1',
        );
        expect(
          NotificationActionResolver.resolve(action),
          AppRoutes.aiAnalysisAttempt('attempt-1'),
        );
      },
    );

    test('none resolves to null', () {
      expect(
        NotificationActionResolver.resolve(const NotificationAction()),
        isNull,
      );
    });

    test('unknown resolves to null rather than throwing', () {
      const action = NotificationAction(type: NotificationActionType.unknown);
      expect(NotificationActionResolver.resolve(action), isNull);
    });
  });
}
