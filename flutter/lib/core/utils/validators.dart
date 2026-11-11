import 'package:yalla_5roga/core/constants/app_constants.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/utils/digit_utils.dart';

class Validators {
  const Validators._();

  static final RegExp _emailPattern = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );

  /// Uppercase, lowercase, digit, and symbol required.
  static final RegExp _passwordUpper = RegExp(r'[A-Z]');
  static final RegExp _passwordLower = RegExp(r'[a-z]');
  static final RegExp _passwordDigit = RegExp(r'[0-9]');
  static final RegExp _passwordSymbol = RegExp(r'[^A-Za-z0-9]');

  static String? required(String? value, L10n l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }
    return null;
  }

  /// Display / full name: 3–30 characters after trim.
  static String? name(String? value, L10n l10n) {
    final requiredError = required(value, l10n);
    if (requiredError != null) return requiredError;
    final trimmed = value!.trim();
    if (trimmed.length < AppConstants.minNameLength) {
      return l10n.nameTooShort;
    }
    if (trimmed.length > AppConstants.maxNameLength) {
      return l10n.nameTooLong;
    }
    return null;
  }

  /// Outing / special-event title: 3–20 characters after trim.
  static String? outingName(String? value, L10n l10n) {
    final requiredError = required(value, l10n);
    if (requiredError != null) return requiredError;
    final trimmed = value!.trim();
    if (trimmed.length < AppConstants.minNameLength) {
      return l10n.nameTooShort;
    }
    if (trimmed.length > AppConstants.maxOutingNameLength) {
      return l10n.outingNameTooLong;
    }
    return null;
  }

  static const localPhoneLength = 10;

  /// National number without `+20` / leading `0` (Western digits).
  static String localPhoneDigits(String value) {
    final digits = DigitUtils.westernDigitsOnly(value);
    var local = digits.startsWith('20') ? digits.substring(2) : digits;
    if (local.startsWith('0')) local = local.substring(1);
    return local;
  }

  static String? phone(String? value, L10n l10n) {
    final requiredError = required(value, l10n);
    if (requiredError != null) return requiredError;
    final local = localPhoneDigits(value!);
    if (local.length < localPhoneLength) {
      return l10n.phoneMustBe10Digits;
    }
    if (!RegExp(r'^1[0125]\d{8}$').hasMatch(local)) {
      return l10n.invalidPhone;
    }
    return null;
  }

  /// Always returns E.164 with Western digits for Firebase / REST.
  static String normalizePhone(String value) => '+20${localPhoneDigits(value)}';

  static String? normalizeGroupPhone(String value) {
    final raw = value.trim();
    if (raw.isEmpty || RegExp(r'[a-zA-Z]').hasMatch(raw)) return null;
    final digits = DigitUtils.westernDigitsOnly(raw);
    if (raw.startsWith('+') || digits.startsWith('00')) {
      final international = raw.startsWith('+') ? digits : digits.substring(2);
      if (RegExp(r'^[1-9]\d{6,14}$').hasMatch(international)) {
        return '+$international';
      }
      return null;
    }
    return isValidEgyptianPhone(raw) ? normalizePhone(raw) : null;
  }

  static bool isValidEgyptianPhone(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return RegExp(r'^1[0125]\d{8}$').hasMatch(localPhoneDigits(value));
  }

  static String? email(String? value, L10n l10n) {
    final requiredError = required(value, l10n);
    if (requiredError != null) return requiredError;
    final email = value!.trim();
    if (!_emailPattern.hasMatch(email)) {
      return l10n.invalidEmail;
    }
    return null;
  }

  /// Password: min length, upper, lower, digit, and symbol.
  static String? password(String? value, L10n l10n) {
    final requiredError = required(value, l10n);
    if (requiredError != null) return requiredError;
    final password = value!;
    if (password.length < AppConstants.minPasswordLength ||
        !_passwordUpper.hasMatch(password) ||
        !_passwordLower.hasMatch(password) ||
        !_passwordDigit.hasMatch(password) ||
        !_passwordSymbol.hasMatch(password)) {
      return l10n.passwordRequirements;
    }
    return null;
  }

  static const otpLength = 6;

  static String? otp(String? value, L10n l10n) {
    final requiredError = required(value, l10n);
    if (requiredError != null) return requiredError;
    final code = DigitUtils.westernDigitsOnly(value!);
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      return l10n.invalidOtp;
    }
    return null;
  }

  /// OTP payload for the API (Western digits only).
  static String normalizeOtp(String value) =>
      DigitUtils.westernDigitsOnly(value);
}
