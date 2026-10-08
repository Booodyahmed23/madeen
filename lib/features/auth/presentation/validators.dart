import 'package:flutter/widgets.dart';

import '../../../l10n/generated/app_localizations.dart';

/// Client-side validation is UX only — a fast first pass so a user doesn't
/// round-trip to the server for an obviously empty field. The backend's
/// class-validator DTOs (RegisterDto/ResetPasswordDto) remain the actual
/// authority (ARCHITECTURE.md §21) and are re-checked on every submit
/// regardless of what passes here.
class AuthValidators {
  const AuthValidators._();

  static String? email(BuildContext context, String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) return l10n.validationRequired;
    if (value.trim().length > maxEmailLength) {
      return l10n.validationInvalidEmail;
    }
    final pattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!pattern.hasMatch(value.trim())) return l10n.validationInvalidEmail;
    return null;
  }

  static String? password(BuildContext context, String? value) {
    final l10n = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) return l10n.validationRequired;
    if (value.length < minPasswordLength) {
      return l10n.validationPasswordTooShort;
    }
    if (value.length > maxPasswordLength) return l10n.validationPasswordTooLong;
    return null;
  }

  /// The API's password rule for register, reset and change password
  /// (contract §A1) — length only, the same as the website.
  static const minPasswordLength = 8;
  static const maxPasswordLength = 200;

  /// The API's `email` limit.
  static const maxEmailLength = 254;

  /// The API's first/last name limit (1–100).
  static const maxNameLength = 100;

  static String? name(BuildContext context, String? value) {
    final requiredError = required(context, value);
    if (requiredError != null) return requiredError;
    if (value!.trim().length > maxNameLength) {
      return AppLocalizations.of(context)!.validationNameTooLong;
    }
    return null;
  }

  static String? required(BuildContext context, String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppLocalizations.of(context)!.validationRequired;
    }
    return null;
  }
}
