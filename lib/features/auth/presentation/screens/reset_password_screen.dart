import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/error/result.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../providers/auth_notifier.dart';
import '../validators.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/password_field.dart';

/// Reached from Forgot Password's "Already have a reset code?" link (the
/// only in-app entry point), or via `initialToken` from a `?token=...`
/// query — no native universal/app link is configured yet, and the
/// backend's emailed link currently targets the web app
/// (`WEB_APP_URL/reset-password`), so on mobile the user pastes the token
/// from that link. The dev-only console email provider prints the same
/// link (see backend ConsoleEmailProvider).
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, this.initialToken});

  final String? initialToken;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _tokenController = TextEditingController(
    text: widget.initialToken,
  );
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _succeeded = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final result = await ref
        .read(authNotifierProvider.notifier)
        .resetPassword(
          token: _tokenController.text.trim(),
          newPassword: _passwordController.text,
        );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      if (result is Success<void>) _succeeded = true;
      if (result is Failure<void>) _failure = result.failure;
    });
  }

  /// The client already enforces the backend's password rules, so a 400
  /// from `/auth/reset-password` means the token was rejected.
  bool get _tokenRejected => _failure is ValidationFailure;

  String? _errorMessage(AppLocalizations l10n) {
    final failure = _failure;
    if (failure == null) return null;
    if (_tokenRejected) return l10n.resetPasswordInvalidToken;
    return localizedFailureMessage(l10n, failure);
  }

  /// A server error describes the last submit, not what's in the form
  /// now — drop it as soon as the user edits anything.
  void _clearFailure() {
    if (_failure != null) setState(() => _failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MadeenSpace.lg),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const MadeenBrandHeader(),
                  const SizedBox(height: MadeenSpace.xl),
                  Text(
                    l10n.resetPasswordTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_succeeded) ...[
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.resetPasswordSuccessMessage,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: Text(l10n.loginSubmit),
                    ),
                  ] else
                    Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: _clearFailure,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthErrorBanner(message: _errorMessage(l10n)),
                          if (_tokenRejected)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: TextButton(
                                onPressed: () => context.canPop()
                                    ? context.pop()
                                    : context.go(AppRoutes.forgotPassword),
                                child: Text(l10n.resetPasswordRequestNewCode),
                              ),
                            ),
                          TextFormField(
                            controller: _tokenController,
                            autocorrect: false,
                            enableSuggestions: false,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: l10n.resetPasswordTokenLabel,
                            ),
                            validator: (value) =>
                                AuthValidators.required(context, value),
                          ),
                          const SizedBox(height: 16),
                          PasswordField(
                            controller: _passwordController,
                            labelText: l10n.resetPasswordNewPasswordLabel,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) =>
                                AuthValidators.password(context, value),
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(l10n.resetPasswordSubmit),
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
    );
  }
}
