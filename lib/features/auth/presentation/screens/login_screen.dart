import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../../../../core/router/app_router.dart';
import '../providers/auth_notifier.dart';
import '../validators.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/password_field.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _emailController.dispose();
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
        .login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;
    final failure = result.when(success: (_) => null, failure: (f) => f);
    // Lets the platform offer to save the credentials it just autofilled
    // or watched being typed — only once they're known to be correct.
    if (failure == null) TextInput.finishAutofillContext();
    setState(() {
      _isSubmitting = false;
      _failure = failure;
    });
    // On success, the router's redirect (driven by AuthState) takes over —
    // no manual navigation needed here.
  }

  /// A 401 from `/auth/login` means wrong credentials, not an expired
  /// session — the generic mapping would say the latter.
  String? _errorMessage(AppLocalizations l10n) {
    final failure = _failure;
    if (failure == null) return null;
    if (failure is UnauthorizedFailure) return l10n.authInvalidCredentials;
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(MadeenSpace.lg),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                // Only a successful submit (finishAutofillContext) offers to save
                // credentials — leaving the screen must not, or iOS prompts to
                // save a password that was never accepted.
                onDisposeAction: AutofillContextAction.cancel,
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  onChanged: _clearFailure,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MadeenBrandHeader(),
                      const SizedBox(height: MadeenSpace.xl),
                      Text(
                        l10n.loginTitle,
                        style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      AuthErrorBanner(message: _errorMessage(l10n)),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: l10n.authEmailLabel,
                        ),
                        validator: (value) =>
                            AuthValidators.email(context, value),
                      ),
                      const SizedBox(height: 16),
                      PasswordField(
                        controller: _passwordController,
                        labelText: l10n.authPasswordLabel,
                        autofillHints: const [AutofillHints.password],
                        validator: (value) =>
                            AuthValidators.required(context, value),
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () =>
                              context.push(AppRoutes.forgotPassword),
                          child: Text(l10n.loginForgotPassword),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                            : Text(l10n.loginSubmit),
                      ),
                      const SizedBox(height: 16),
                      // Wrap, not Row: "Don't have an account? Create one"
                      // can exceed a narrow phone width at larger
                      // text-scale settings — Wrap drops to a second line
                      // instead of overflowing.
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(l10n.loginNoAccount),
                          TextButton(
                            onPressed: () => context.push(AppRoutes.register),
                            child: Text(l10n.loginCreateAccount),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
