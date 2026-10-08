import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:mobile/app/widgets/ai_analysis_teaser_card.dart';
import 'package:mobile/core/router/app_router.dart';
import 'package:mobile/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile/features/auth/domain/entities/auth_session.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/subscription/access_overrides.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

const _session = AuthSession(
  user: AuthUser(
    id: 'user-1',
    email: 'jane@example.com',
    firstName: 'Jane',
    lastName: 'Doe',
    role: 'USER',
  ),
  accessToken: 'access-token-1',
);

/// V1 defaults: no V2 switch is overridden here.
void main() {
  late ProviderContainer container;

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = MockAuthRepository();
    when(() => auth.restoreSession()).thenAnswer((_) async => _session);
    container = ProviderContainer(
      overrides: [
        ...accessOverrides(),
        authRepositoryProvider.overrideWithValue(auth),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Home shows no AI or course entry points in V1', (tester) async {
    await pumpApp(tester);

    expect(find.text('Exam Simulation'), findsOneWidget);
    expect(find.byType(AiAnalysisTeaserCard), findsNothing);
    expect(find.text('AI Tutor'), findsNothing);
    expect(find.byIcon(Icons.ondemand_video_outlined), findsNothing);
  });

  for (final route in [
    AppRoutes.aiTutor,
    AppRoutes.courses,
    AppRoutes.courseDetail('course-1'),
    AppRoutes.aiAnalysisOverview,
    AppRoutes.aiAnalysisAttempt('a1'),
  ]) {
    testWidgets('$route is closed in V1 and lands on Home', (tester) async {
      await pumpApp(tester);

      container.read(appRouterProvider).go(route);
      await tester.pumpAndSettle();

      expect(find.text('Pass CMA & FMAA with confidence'), findsOneWidget);
    });
  }
}
