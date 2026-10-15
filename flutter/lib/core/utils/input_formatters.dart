import 'package:flutter/services.dart';
import 'package:yalla_5roga/core/utils/digit_utils.dart';

class InputFormatters {
  const InputFormatters._();

  static final TextInputFormatter noSpaces = FilteringTextInputFormatter.deny(
    RegExp(r'\s'),
  );

  static final TextInputFormatter email = FilteringTextInputFormatter.allow(
    RegExp(r'[a-zA-Z0-9@._\-]'),
  );

  /// Western + Arabic-Indic + Persian digits.
  static final TextInputFormatter digitsOnly =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]'));

  /// Keeps only digits, optionally renders Arabic-Indic for Arabic UI.
  static TextInputFormatter localizedDigits({
    required bool arabicDisplay,
    int? maxLength,
  }) {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      var western = DigitUtils.westernDigitsOnly(newValue.text);
      if (maxLength != null && western.length > maxLength) {
        western = western.substring(0, maxLength);
      }
      final text = arabicDisplay ? DigitUtils.toEastern(western) : western;
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  static TextInputFormatter maxLength(int length) {
    return LengthLimitingTextInputFormatter(length);
  }
}
