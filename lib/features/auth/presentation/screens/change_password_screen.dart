import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../providers/auth_notifier.dart';
import '../validators.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/password_field.dart';

/// `POST /auth/change-password`, reached from Profile. This device stays
/// signed in with the new tokens; the server signs out every other device.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
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
        .changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );

    if (!mounted) return;
    switch (result) {
      case Success():
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.changePasswordSuccess)));
        context.pop();
      case Failure(:final failure):
        setState(() {
          _isSubmitting = false;
          _failure = failure;
        });
    }
  }

  /// A server error describes the last submit — drop it once the user
  /// edits anything.
  void _clearFailure() {
    if (_failure != null) setState(() => _failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final failure = _failure;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.changePasswordTitle)),
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
                onChanged: _clearFailure,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AuthErrorBanner(
                        message: failure == null
                            ? null
                            : localizedFailureMessage(l10n, failure),
                      ),
                      PasswordField(
                        controller: _currentController,
                        labelText: l10n.changePasswordCurrentLabel,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            AuthValidators.required(context, value),
                      ),
                      const SizedBox(height: MadeenSpace.md),
                      PasswordField(
                        controller: _newController,
                        labelText: l10n.changePasswordNewLabel,
                        autofillHints: const [AutofillHints.newPassword],
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            AuthValidators.password(context, value),
                      ),
                      const SizedBox(height: MadeenSpace.md),
                      PasswordField(
                        controller: _confirmController,
                        labelText: l10n.changePasswordConfirmLabel,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: (value) => value == _newController.text
                            ? null
                            : l10n.changePasswordMismatch,
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: MadeenSpace.sm),
                      Text(
                        l10n.changePasswordOtherDevicesNote,
                        style: MadeenType.bodySm.copyWith(
                          color: t.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: MadeenSpace.lg),
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
                            : Text(l10n.changePasswordSubmit),
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
