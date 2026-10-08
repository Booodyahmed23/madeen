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

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _submitted = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _emailController.dispose();
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
        .forgotPassword(_emailController.text.trim());

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      // Shown regardless of whether the email exists — the backend response
      // is identical either way (no user enumeration), and the UI mirrors
      // that: success state, not a per-email outcome.
      if (result is Success<void>) _submitted = true;
      if (result is Failure<void>) _failure = result.failure;
    });
  }

  /// A server error describes the last submit, not what's in the form
  /// now — drop it as soon as the user edits anything.
  void _clearFailure() {
    if (_failure != null) setState(() => _failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final failure = _failure;

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
                    l10n.forgotPasswordTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (_submitted)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        l10n.forgotPasswordSuccessMessage,
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      onChanged: _clearFailure,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.forgotPasswordDescription,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          AuthErrorBanner(
                            message: failure == null
                                ? null
                                : localizedFailureMessage(l10n, failure),
                          ),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.send,
                            autocorrect: false,
                            autofillHints: const [AutofillHints.email],
                            decoration: InputDecoration(
                              labelText: l10n.authEmailLabel,
                            ),
                            validator: (value) =>
                                AuthValidators.email(context, value),
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
                                : Text(l10n.forgotPasswordSubmit),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  // The only in-app way to the Reset Password screen: the
                  // emailed link targets the web app, and no native deep
                  // link is configured — see ResetPasswordScreen.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(l10n.forgotPasswordHaveCode),
                      TextButton(
                        onPressed: () => context.push(AppRoutes.resetPassword),
                        child: Text(l10n.forgotPasswordEnterCode),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: Text(l10n.forgotPasswordBackToLogin),
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
