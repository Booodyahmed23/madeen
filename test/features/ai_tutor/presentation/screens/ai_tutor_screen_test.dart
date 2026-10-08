import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/error/app_failure.dart';
import 'package:mobile/core/error/result.dart';
import 'package:mobile/features/ai_tutor/data/repositories/tutor_repository_impl.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_message.dart';
import 'package:mobile/features/ai_tutor/domain/entities/tutor_message_role.dart';
import 'package:mobile/features/ai_tutor/domain/repositories/tutor_repository.dart';
import 'package:mobile/features/ai_tutor/presentation/screens/ai_tutor_screen.dart';
import 'package:mobile/l10n/generated/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTutorRepository extends Mock implements TutorRepository {}

TutorMessage _assistantMessage(String content) => TutorMessage(
  id: 'assistant-1',
  role: TutorMessageRole.assistant,
  content: content,
  timestamp: DateTime(2026, 9, 1),
);

Widget _wrap(
  TutorRepository repository, {
  Locale locale = const Locale('en'),
  ThemeMode themeMode = ThemeMode.light,
}) {
  return ProviderScope(
    overrides: [tutorRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      locale: locale,
      theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      themeMode: themeMode,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AiTutorScreen(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  setUpAll(() {
    registerFallbackValue(<TutorMessage>[]);
  });

  testWidgets('shows the welcome state with suggested prompts when empty', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(MockTutorRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Ask me anything about your studies'), findsOneWidget);
    expect(find.text('What is variance analysis?'), findsOneWidget);
    expect(find.text('Explain contribution margin.'), findsOneWidget);
  });

  testWidgets('tapping a suggested prompt sends it as a user message', (
    tester,
  ) async {
    final repository = MockTutorRepository();
    when(
      () => repository.sendMessage(
        history: any(named: 'history'),
        content: any(named: 'content'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async => Result.success(_assistantMessage('Reply.')));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.tap(find.text('What is variance analysis?'));
    await tester.pumpAndSettle();

    expect(find.text('What is variance analysis?'), findsOneWidget);
    expect(find.text('Reply.'), findsOneWidget);
  });

  testWidgets('shows a typing indicator while the reply is pending', (
    tester,
  ) async {
    final repository = MockTutorRepository();
    final completer = Completer<Result<TutorMessage>>();
    when(
      () => repository.sendMessage(
        history: any(named: 'history'),
        content: any(named: 'content'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) => completer.future);

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(find.text('AI Tutor is typing…'), findsOneWidget);

    completer.complete(Result.success(_assistantMessage('Reply.')));
    await tester.pumpAndSettle();
    expect(find.text('AI Tutor is typing…'), findsNothing);
  });

  testWidgets('shows an inline error message when sending fails', (
    tester,
  ) async {
    final repository = MockTutorRepository();
    when(
      () => repository.sendMessage(
        history: any(named: 'history'),
        content: any(named: 'content'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async => const Result.failure(NetworkFailure()));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('Network error. Please try again.'), findsOneWidget);
    // The student's own message is never lost by a failed reply.
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('new conversation clears messages after confirming', (
    tester,
  ) async {
    final repository = MockTutorRepository();
    when(
      () => repository.sendMessage(
        history: any(named: 'history'),
        content: any(named: 'content'),
        languageCode: any(named: 'languageCode'),
      ),
    ).thenAnswer((_) async => Result.success(_assistantMessage('Reply.')));

    await tester.pumpWidget(_wrap(repository));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'hello');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(find.text('hello'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add_comment_outlined));
    await tester.pumpAndSettle();
    expect(find.text('New conversation'), findsWidgets); // dialog title+action
    await tester.tap(find.widgetWithText(TextButton, 'New conversation'));
    await tester.pumpAndSettle();

    expect(find.text('hello'), findsNothing);
    expect(find.text('Ask me anything about your studies'), findsOneWidget);
  });

  testWidgets('renders in Arabic (RTL) without crashing', (tester) async {
    await tester.pumpWidget(
      _wrap(MockTutorRepository(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('اسألني أي شيء عن مذاكرتك'), findsOneWidget);
    final directionality = tester.widget<Directionality>(
      find.byType(Directionality).first,
    );
    expect(directionality.textDirection, TextDirection.rtl);
  });

  testWidgets('renders in dark mode without crashing', (tester) async {
    await tester.pumpWidget(
      _wrap(MockTutorRepository(), themeMode: ThemeMode.dark),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ask me anything about your studies'), findsOneWidget);
    final context = tester.element(find.byType(AiTutorScreen));
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('the send button is accessible via semantics', (tester) async {
    await tester.pumpWidget(_wrap(MockTutorRepository()));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.byIcon(Icons.send));
    expect(semantics.label, 'Send');
  });
}
