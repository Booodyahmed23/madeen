import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/error/failure_messages.dart';
import '../../../../core/error/result.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/madeen/madeen.dart';
import '../providers/auth_notifier.dart';
import '../validators.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/password_field.dart';

/// `DELETE /users/me`, reached from Profile — required in-app by the App
/// Store and Google Play. Explains that deletion can't be undone, asks for
/// the password, and confirms once more. On success the notifier wipes
/// local data and signs out, and the router's auth redirect lands on Login.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() =>
      _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  AppFailure? _failure;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    if (!await _confirm()) return;
    if (!mounted) return;

    setState(() {
      _isSubmitting = true;
      _failure = null;
    });

    final result = await ref
        .read(authNotifierProvider.notifier)
        .deleteAccount(_passwordController.text);

    if (!mounted) return;
    if (result is Failure<void>) {
      setState(() {
        _isSubmitting = false;
        _failure = result.failure;
      });
    }
  }

  Future<bool> _confirm() async {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountConfirmTitle),
        content: Text(l10n.deleteAccountConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.authCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.deleteAccountSubmit),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  void _clearFailure() {
    if (_failure != null) setState(() => _failure = null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MadeenTokens.of(context);
    final failure = _failure;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.deleteAccountTitle)),
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
                onChanged: _clearFailure,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: t.error),
                        const SizedBox(width: MadeenSpace.xs),
                        Expanded(
                          child: Text(
                            l10n.deleteAccountHeading,
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(color: t.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MadeenSpace.sm),
                    Text(
                      l10n.deleteAccountExplanation,
                      style: MadeenType.bodyMd.copyWith(color: t.ink),
                    ),
                    const SizedBox(height: MadeenSpace.lg),
                    AuthErrorBanner(
                      message: failure == null
                          ? null
                          : localizedFailureMessage(l10n, failure),
                    ),
                    PasswordField(
                      controller: _passwordController,
                      labelText: l10n.deleteAccountPasswordLabel,
                      autofillHints: const [AutofillHints.password],
                      validator: (value) =>
                          AuthValidators.required(context, value),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: MadeenSpace.lg),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: t.error),
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.deleteAccountSubmit),
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
