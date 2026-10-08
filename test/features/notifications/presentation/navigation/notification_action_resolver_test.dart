import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/notifications/domain/entities/notification_action.dart';
import 'package:mobile/features/notifications/presentation/navigation/notification_action_resolver.dart';

String? resolve(NotificationActionType type, {String? targetId}) =>
    NotificationActionResolver.resolve(
      NotificationAction(type: type, targetId: targetId),
    );

void main() {
  test('OPEN_STUDY_SETUP goes to the topic, or the curriculum without one', () {
    expect(
      resolve(NotificationActionType.openStudySetup, targetId: 'topic-1'),
      AppRoutes.curriculumTopicDetail('topic-1'),
    );
    expect(
      resolve(NotificationActionType.openStudySetup),
      AppRoutes.curriculum,
    );
  });

  test('setup, performance and plans need no id', () {
    expect(resolve(NotificationActionType.openExamSetup), AppRoutes.examSetup);
    expect(
      resolve(NotificationActionType.openPerformance),
      AppRoutes.performanceOverview,
    );
    expect(
      resolve(NotificationActionType.openTopicPerformance),
      AppRoutes.performanceTopics,
    );
    expect(resolve(NotificationActionType.openPlans), AppRoutes.plans);
  });

  test('OPEN_ATTEMPT needs its id', () {
    expect(
      resolve(NotificationActionType.openAttempt, targetId: 'a1'),
      AppRoutes.performanceAttemptDetail('a1'),
    );
    expect(resolve(NotificationActionType.openAttempt), isNull);
  });

  test('no action and unknown actions show the details instead', () {
    expect(resolve(NotificationActionType.none), isNull);
    expect(resolve(NotificationActionType.unknown), isNull);
  });
}
