import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/locale_provider.dart';
import '../core/router/app_router.dart';
import '../core/theme/theme_mode_provider.dart';
import '../features/auth/domain/entities/auth_user.dart';
import '../features/auth/presentation/providers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_state.dart';
import '../features/auth/presentation/widgets/logout_confirmation.dart';
import '../features/exam_simulation/presentation/providers/exam_notifier.dart';
import '../features/exam_simulation/presentation/providers/exam_state.dart';
import '../features/notifications/presentation/providers/notifications_providers.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/widgets/madeen/madeen.dart';
import 'widgets/ai_analysis_teaser_card.dart';
import 'widgets/continue_exam_card.dart';
import 'widgets/continue_study_card.dart';
import 'widgets/performance_snapshot_card.dart';
import 'widgets/recent_activity_section.dart';
import 'widgets/upcoming_reminder_card.dart';

/// The student dashboard — the authenticated landing screen (gated by the
/// router's redirect, see core/router/app_router.dart). Pure composition:
/// every number on it is read from an existing feature's own provider
/// (see each section widget's own doc comment for which one) — this file
/// never fetches or computes a metric itself, beyond the one small, pure,
/// unpersisted "next reminder" view in `next_study_reminder.dart`.
///
/// The MADEEN design's reference screen (Phase 14A); the theme itself is
/// applied app-wide by app/app.dart.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _HomeView();
  }
}

class _HomeView extends ConsumerWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final authState = ref.watch(authNotifierProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final unreadCount = ref.watch(unreadNotificationCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: t.canvas,
      appBar: AppBar(
        titleSpacing: MadeenSpace.pageMargin,
        title: Text(l10n.appName),
        actions: [
          Semantics(
            label: unreadCount > 0
                ? l10n.notificationsUnreadBadgeSemantic(unreadCount)
                : l10n.notificationsBellTooltip,
            button: true,
            excludeSemantics: true,
            child: IconButton(
              icon: Badge(
                label: Text('$unreadCount'),
                isLabelVisible: unreadCount > 0,
                child: const Icon(Icons.notifications_outlined),
              ),
              tooltip: l10n.notificationsBellTooltip,
              onPressed: () => context.push(AppRoutes.notifications),
            ),
          ),
          if (user != null) const _ProfileButton(),
          IconButton(
            // Icons.logout isn't direction-aware: mirror it so the arrow
            // still points out of the door in RTL.
            icon: Transform.flip(
              flipX: Directionality.of(context) == TextDirection.rtl,
              child: const Icon(Icons.logout),
            ),
            tooltip: l10n.navLogout,
            onPressed: () => confirmAndLogout(context, ref),
          ),
          const SizedBox(width: MadeenSpace.xs),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(MadeenSize.hairline),
          child: Divider(color: t.hairline),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MadeenSpace.pageMargin,
            MadeenSpace.md,
            MadeenSpace.pageMargin,
            MadeenSpace.xl,
          ),
          children: [
            _GreetingHero(user: user),
            const SizedBox(height: MadeenSpace.lg),
            const ContinueExamCard(),
            const ContinueStudyCard(),
            const PerformanceSnapshotCard(),
            const SizedBox(height: MadeenSpace.md),
            const AiAnalysisTeaserCard(),
            const SizedBox(height: MadeenSpace.md),
            const RecentActivitySection(),
            const SizedBox(height: MadeenSpace.md),
            const UpcomingReminderCard(),
            const SizedBox(height: MadeenSpace.md),
            const _FeatureTiles(),
            const SizedBox(height: MadeenSpace.xl),
            const _SettingsSection(),
          ],
        ),
      ),
    );
  }
}

/// The reference's account button: a solid ink square holding the person
/// glyph.
class _ProfileButton extends StatelessWidget {
  const _ProfileButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    return IconButton(
      tooltip: l10n.navProfile,
      onPressed: () => context.push(AppRoutes.profile),
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: t.primaryAction,
          borderRadius: BorderRadius.circular(MadeenRadius.card),
        ),
        child: Icon(Icons.person_outline, size: 20, color: t.onPrimaryAction),
      ),
    );
  }
}

/// The deep-slate hero: a brass rule, the serif greeting, the app's
/// tagline, and Home's primary action (Start Studying) — the reference's
/// "track" panel, carrying only what Home actually knows (the signed-in
/// user's first name).
class _GreetingHero extends StatelessWidget {
  const _GreetingHero({required this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final user = this.user;
    final greeting = user != null
        ? l10n.homeGreeting(user.firstName)
        : l10n.homeGreetingFallback;

    return MadeenCard(
      tone: MadeenCardTone.hero,
      padding: const EdgeInsets.fromLTRB(
        MadeenSpace.lg,
        MadeenSpace.lg,
        MadeenSpace.lg,
        MadeenSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 28, height: 2, color: t.heroAccent),
          const SizedBox(height: MadeenSpace.md),
          Text(
            greeting,
            style: Theme.of(context).textTheme.headlineLarge!
                .copyWith(color: t.onHero),
          ),
          const SizedBox(height: MadeenSpace.xs),
          Text(
            l10n.homeTitle,
            style: MadeenType.bodyMd.copyWith(color: t.onHeroMuted),
          ),
          const SizedBox(height: MadeenSpace.lg),
          // The one primary action on Home, in burnished brass — the
          // design reserves the accent for "selected key paths".
          MadeenPrimaryButton(
            label: l10n.homeStartStudying,
            icon: Icons.play_circle_outline,
            backgroundColor: t.accent,
            foregroundColor: t.hero,
            onPressed: () => context.push(AppRoutes.curriculum),
          ),
        ],
      ),
    );
  }
}

/// The four entry points as a two-column tile grid. Titles reuse each
/// feature's own nav/entry-point strings verbatim (the same visible text
/// the router tests look for). AI Tutor is disabled while an Exam
/// Simulation attempt is in progress — the router's redirect is still the
/// actual enforcement (see `AppRoutes.aiTutor`).
class _FeatureTiles extends ConsumerWidget {
  const _FeatureTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final examState = ref.watch(examNotifierProvider);
    final examInProgress =
        examState is ExamActive ||
        examState is ExamTimedOut ||
        examState is ExamSubmitting;

    return MadeenPairGrid(
      spacing: MadeenSpace.sm,
      children: [
        MadeenFeatureTile(
          icon: Icons.auto_awesome_outlined,
          title: l10n.aiTutorTitle,
          subtitle: examInProgress
              ? l10n.aiTutorUnavailableDuringExam
              : l10n.aiTutorHomeCardSubtitle,
          onTap: examInProgress ? null : () => context.push(AppRoutes.aiTutor),
        ),
        MadeenFeatureTile(
          icon: Icons.timer_outlined,
          title: l10n.navExamSimulation,
          subtitle: l10n.homeExamSimulationCardSubtitle,
          onTap: () => context.push(AppRoutes.examSetup),
        ),
        MadeenFeatureTile(
          icon: Icons.menu_book_outlined,
          title: l10n.navCurriculum,
          subtitle: l10n.homeCurriculumCardSubtitle,
          onTap: () => context.push(AppRoutes.curriculum),
        ),
        MadeenFeatureTile(
          icon: Icons.ondemand_video_outlined,
          title: l10n.courseHomeCardTitle,
          subtitle: l10n.courseHomeCardSubtitle,
          onTap: () => context.push(AppRoutes.courses),
        ),
      ],
    );
  }
}

/// Theme and language preferences as pill segmented controls (DESIGN.md
/// "Tactile Pill Segmented Controls"), styled by the MADEEN theme.
class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MadeenSectionHeader(title: l10n.settingsTheme),
        const SizedBox(height: MadeenSpace.sm),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight)),
            ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
            ButtonSegment(
              value: ThemeMode.system,
              label: Text(l10n.themeSystem),
            ),
          ],
          selected: {themeMode},
          onSelectionChanged: (selection) => ref
              .read(themeModeProvider.notifier)
              .setThemeMode(selection.first),
        ),
        const SizedBox(height: MadeenSpace.lg),
        MadeenSectionHeader(title: l10n.settingsLanguage),
        const SizedBox(height: MadeenSpace.sm),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'en', label: Text('English')),
            ButtonSegment(value: 'ar', label: Text('العربية')),
          ],
          selected: {locale?.languageCode ?? 'en'},
          onSelectionChanged: (selection) => ref
              .read(localeProvider.notifier)
              .setLocale(Locale(selection.first)),
        ),
      ],
    );
  }
}
