import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/error/result.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../domain/entities/auth_user.dart';
import '../providers/auth_notifier.dart';
import '../providers/auth_state.dart';
import '../validators.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/logout_confirmation.dart';

/// The signed-in user's own profile. Only what the backend supports is
/// editable — first and last name via `PATCH /users/me`; password change
/// and account deletion open their own screens. Email is shown read-only;
/// email change, avatar and session management have no backend endpoints,
/// so they are deliberately not offered here (see features/auth/README.md).
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstNameController;
  late final TextEditingController _lastNameController;
  bool _isLoading = true;
  AppFailure? _loadFailure;
  bool _isSubmitting = false;
  bool _saved = false;
  AppFailure? _saveFailure;

  @override
  void initState() {
    super.initState();
    final user = _currentUser();
    _firstNameController = TextEditingController(text: user?.firstName ?? '')
      ..addListener(_onEdited);
    _lastNameController = TextEditingController(text: user?.lastName ?? '')
      ..addListener(_onEdited);
    _load(initial: true);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  AuthUser? _currentUser() {
    final state = ref.read(authNotifierProvider);
    return state is AuthAuthenticated ? state.user : null;
  }

  /// Fetches the user fresh from the server. The form already shows the
  /// session's cached copy, so a failure here is non-blocking.
  Future<void> _load({bool initial = false}) async {
    // `_isLoading` already starts true; setState isn't allowed in initState.
    if (!initial) {
      setState(() {
        _isLoading = true;
        _loadFailure = null;
      });
    }
    // Snapshot what the form shows now: if it's unchanged when the response
    // arrives, the user hasn't typed, so the fresh values can replace it.
    // (Comparing against the session user afterwards doesn't work — the
    // refresh has already replaced it by then.)
    final firstBefore = _firstNameController.text;
    final lastBefore = _lastNameController.text;
    final result = await ref
        .read(authNotifierProvider.notifier)
        .refreshCurrentUser();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      switch (result) {
        case Success(:final value):
          // Never overwrite what the user has started typing.
          if (_firstNameController.text == firstBefore &&
              _lastNameController.text == lastBefore) {
            _firstNameController.text = value.firstName;
            _lastNameController.text = value.lastName;
          }
        case Failure(:final failure):
          _loadFailure = failure;
      }
    });
  }

  bool get _isDirty {
    final user = _currentUser();
    if (user == null) return false;
    return _firstNameController.text.trim() != user.firstName ||
        _lastNameController.text.trim() != user.lastName;
  }

  void _onEdited() {
    // Rebuilds the Save button's enabled state, and clears a stale "saved"
    // confirmation once the user edits again.
    setState(() => _saved = _saved && !_isDirty);
  }

  Future<void> _save() async {
    if (_isSubmitting || !_isDirty) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _saved = false;
      _saveFailure = null;
    });

    final result = await ref
        .read(authNotifierProvider.notifier)
        .updateProfile(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
        );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _saved = result is Success<AuthUser>;
      _saveFailure = result.when(success: (_) => null, failure: (f) => f);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final state = ref.watch(authNotifierProvider);
    final user = state is AuthAuthenticated ? state.user : null;
    final saveFailure = _saveFailure;
    final canSave = !_isSubmitting && !_isLoading && _isDirty;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
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
        ],
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(),
              )
            : null,
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              MadeenSpace.pageMargin,
              MadeenSpace.lg,
              MadeenSpace.pageMargin,
              MadeenSpace.xl,
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (user != null) ...[
                      _ProfileHeader(user: user),
                      const SizedBox(height: MadeenSpace.lg),
                    ],
                    if (_loadFailure != null) _LoadFailedNotice(onRetry: _load),
                    AuthErrorBanner(
                      message: saveFailure == null
                          ? null
                          : localizedFailureMessage(l10n, saveFailure),
                    ),
                    if (_saved)
                      Padding(
                        padding: const EdgeInsets.only(bottom: MadeenSpace.md),
                        child: Semantics(
                          liveRegion: true,
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: t.success,
                              ),
                              const SizedBox(width: MadeenSpace.xs),
                              Flexible(
                                child: Text(
                                  l10n.profileSavedMessage,
                                  style: MadeenType.bodyMd.copyWith(
                                    color: t.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    MadeenSectionHeader(
                      title: l10n.profilePersonalDetailsSection,
                    ),
                    const SizedBox(height: MadeenSpace.sm),
                    TextFormField(
                      controller: _firstNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l10n.authFirstNameLabel,
                      ),
                      validator: (value) => AuthValidators.name(context, value),
                    ),
                    const SizedBox(height: MadeenSpace.md),
                    TextFormField(
                      controller: _lastNameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: l10n.authLastNameLabel,
                      ),
                      validator: (value) => AuthValidators.name(context, value),
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: MadeenSpace.lg),
                    FilledButton(
                      onPressed: canSave ? _save : null,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.profileSave),
                    ),
                    const SizedBox(height: MadeenSpace.xl),
                    MadeenSectionHeader(title: l10n.profileSettingsSection),
                    const SizedBox(height: MadeenSpace.sm),
                    MadeenCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MadeenSpace.md,
                      ),
                      child: MadeenDividedList(
                        children: [
                          _SettingsRow(
                            icon: Icons.workspace_premium_outlined,
                            title: l10n.profilePlans,
                            onTap: () => context.push(AppRoutes.plans),
                          ),
                          _SettingsRow(
                            icon: Icons.notifications_outlined,
                            title: l10n.profileNotificationSettings,
                            onTap: () =>
                                context.push(AppRoutes.notificationPreferences),
                          ),
                          _SettingsRow(
                            icon: Icons.alarm_outlined,
                            title: l10n.profileStudyReminders,
                            onTap: () => context.push(AppRoutes.studyReminders),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: MadeenSpace.xl),
                    MadeenSectionHeader(title: l10n.profileSecuritySection),
                    const SizedBox(height: MadeenSpace.sm),
                    MadeenCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MadeenSpace.md,
                      ),
                      child: MadeenDividedList(
                        children: [
                          _SettingsRow(
                            icon: Icons.lock_outline,
                            title: l10n.profileChangePassword,
                            onTap: () => context.push(AppRoutes.changePassword),
                          ),
                          _SettingsRow(
                            icon: Icons.delete_outline,
                            title: l10n.profileDeleteAccount,
                            destructive: true,
                            onTap: () => context.push(AppRoutes.deleteAccount),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-blocking: the form keeps working with the session's cached copy.
class _LoadFailedNotice extends StatelessWidget {
  const _LoadFailedNotice({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: MadeenSpace.md),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          MadeenSpace.sm,
          MadeenSpace.xxs,
          MadeenSpace.xxs,
          MadeenSpace.xxs,
        ),
        decoration: BoxDecoration(
          color: t.neutralFill,
          borderRadius: BorderRadius.circular(MadeenRadius.card),
          border: Border.all(color: t.hairline),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_outlined, color: t.inkSecondary),
            const SizedBox(width: MadeenSpace.xs),
            Expanded(
              child: Text(
                l10n.profileLoadFailed,
                style: MadeenType.bodySm.copyWith(color: t.ink),
              ),
            ),
            TextButton(onPressed: onRetry, child: Text(l10n.authRetry)),
          ],
        ),
      ),
    );
  }
}

/// The signed-in user's name (serif, editorial) over their email.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    final name = '${user.firstName} ${user.lastName}'.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty) ...[
          Text(
            name,
            style: Theme.of(context).textTheme.headlineLarge!
                .copyWith(color: t.ink),
          ),
          const SizedBox(height: MadeenSpace.xxs),
        ],
        Text(
          user.email,
          style: MadeenType.bodyMd.copyWith(color: t.inkSecondary),
        ),
        const SizedBox(height: MadeenSpace.md),
        Container(width: 32, height: 2, color: t.accent),
      ],
    );
  }
}

/// One navigation row in the Profile settings card.
class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final t = MadeenTokens.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: destructive ? t.error : t.inkSecondary),
      title: Text(
        title,
        style: MadeenType.bodyMd.copyWith(
          color: destructive ? t.error : t.ink,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: t.inkTertiary),
      onTap: onTap,
    );
  }
}
