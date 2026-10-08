import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/core/error/riverpod_retry_policy.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile/features/notifications/data/repositories/notifications_repository_impl.dart';
import 'package:mobile/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile/features/notifications/domain/entities/notification_preferences.dart';
import 'package:mobile/features/notifications/domain/entities/notification_type.dart';
import 'package:mobile/features/notifications/domain/entities/reminder_repeat.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder.dart';
import 'package:mobile/features/notifications/domain/entities/study_reminder_draft.dart';
import 'package:mobile/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../features/subscription/access_overrides.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockNotificationsRepository extends Mock
    implements NotificationsRepository {}

const _user = AuthUser(
  id: 'user-1',
  email: 'jane@example.com',
  firstName: 'Jane',
  lastName: 'Doe',
  role: 'USER',
);
const _session = AuthSession(user: _user, accessToken: 'access-token-1');

final _unread = NotificationItem(
  id: 'notif-1',
  title: 'Continue your CMA preparation',
  body: 'You have not practiced Financial Reporting recently.',
  createdAt: DateTime(2026, 9, 25, 8),
  type: NotificationType.studyReminder,
  isRead: false,
);
final _read = NotificationItem(
  id: 'notif-2',
  title: 'Performance update',
  body: 'Your accuracy improved this week.',
  createdAt: DateTime(2026, 9, 24, 18),
  type: NotificationType.performanceUpdate,
  isRead: true,
);

final _reminder = StudyReminder(
  id: 'reminder-1',
  title: 'Daily CMA Practice',
  enabled: true,
  hour: 7,
  minute: 30,
  repeat: ReminderRepeat.everyDay,
  createdAt: DateTime(2026, 9, 1, 7, 30),
);
final _newReminder = StudyReminder(
  id: 'reminder-2',
  title: 'Evening Review',
  enabled: true,
  hour: 8,
  minute: 0,
  repeat: ReminderRepeat.everyDay,
  createdAt: DateTime(2026, 9, 26),
);

Widget _app({
  required AuthRepository authRepository,
  required NotificationsRepository notificationsRepository,
}) {
  return ProviderScope(
    retry: appRetryPolicy,
    overrides: [
      ...accessOverrides(),
      authRepositoryProvider.overrideWithValue(authRepository),
      notificationsRepositoryProvider.overrideWithValue(
        notificationsRepository,
      ),
    ],
    child: const App(),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationPreferences());
    registerFallbackValue(
      const StudyReminderDraft(
        title: '',
        enabled: true,
        hour: 0,
        minute: 0,
        repeat: ReminderRepeat.everyDay,
      ),
    );
  });

  testWidgets(
    'an unauthenticated user cannot reach /notifications — redirected to login',
    (tester) async {
      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession()).thenAnswer((_) async => null);
      final notificationsRepository = MockNotificationsRepository();

      await tester.pumpWidget(
        _app(
          authRepository: authRepository,
          notificationsRepository: notificationsRepository,
        ),
      );
      await tester.pumpAndSettle();

      verifyNever(() => notificationsRepository.getUnreadCount());
      expect(find.text('Welcome back'), findsOneWidget); // LoginScreen
    },
  );

  testWidgets(
    'Home -> Notifications -> mark as read -> Details, and Profile -> '
    'Notification Settings / Study Reminders -> Editor',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final authRepository = MockAuthRepository();
      when(() => authRepository.restoreSession())
          .thenAnswer((_) async => _session);
      // Profile re-fetches the signed-in user on open.
      when(() => authRepository.getCurrentUser())
          .thenAnswer((_) async => const Result.success(_user));

      final notificationsRepository = MockNotificationsRepository();
      when(() => notificationsRepository.getNotifications())
          .thenAnswer((_) async => Result.success([_unread, _read]));
      when(() => notificationsRepository.getUnreadCount())
          .thenAnswer((_) async => const Result.success(1));
      when(() => notificationsRepository.markAsRead('notif-1'))
          .thenAnswer((_) async => const Result.success(null));
      when(() => notificationsRepository.getNotificationPreferences())
          .thenAnswer(
            (_) async => const Result.success(NotificationPreferences()),
          );
      when(() => notificationsRepository.updateNotificationPreferences(any()))
          .thenAnswer((_) async => const Result.success(null));
      when(() => notificationsRepository.getStudyReminders())
          .thenAnswer((_) async => Result.success([_reminder]));
      when(() => notificationsRepository.createStudyReminder(any()))
          .thenAnswer((_) async => Result.success(_newReminder));

      await tester.pumpWidget(
        _app(
          authRepository: authRepository,
          notificationsRepository: notificationsRepository,
        ),
      );
      await tester.pumpAndSettle();

      // Home shows the bell with the mocked unread count.
      expect(find.text('1'), findsOneWidget);

      // Home -> Notifications.
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsWidgets);
      expect(find.text('Continue your CMA preparation'), findsOneWidget);

      // Tap the unread notification -> marks it read and opens Details.
      // It has no action, so no CTA is shown.
      await tester.tap(find.text('Continue your CMA preparation'));
      await tester.pumpAndSettle();
      expect(
        find.text('You have not practiced Financial Reporting recently.'),
        findsOneWidget,
      );
      expect(
        find.text('No further action for this notification.'),
        findsOneWidget,
      );
      verify(() => notificationsRepository.markAsRead('notif-1')).called(1);

      // Back to the list, then back to Home.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Home -> Profile -> Notification Settings.
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Notification Settings'));
      await tester.pumpAndSettle();
      expect(find.text('Study reminders'), findsOneWidget);

      final studyRemindersSwitch = find
          .widgetWithText(SwitchListTile, 'Study reminders')
          .first;
      await tester.tap(studyRemindersSwitch);
      await tester.pumpAndSettle();
      verify(() => notificationsRepository.updateNotificationPreferences(any()))
          .called(1);

      // Back to Profile -> Study Reminders -> Add Reminder -> Editor ->
      // Save -> back to a list that now also shows the created reminder.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Study Reminders'));
      await tester.pumpAndSettle();
      expect(find.text('Daily CMA Practice'), findsOneWidget);

      await tester.tap(find.text('Add Reminder'));
      await tester.pumpAndSettle();
      expect(find.text('New Reminder'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Evening Review');
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(find.text('New Reminder'), findsNothing); // popped back
      expect(find.text('Evening Review'), findsOneWidget);
      expect(find.text('Daily CMA Practice'), findsOneWidget);
    },
  );
}
