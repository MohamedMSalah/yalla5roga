/// Western ↔ Arabic-Indic digit conversion for locale display and API payloads.
abstract final class DigitUtils {
  static const _eastern = '٠١٢٣٤٥٦٧٨٩';
  static const _persian = '۰۱۲۳۴۵۶۷۸۹';

  /// Converts Arabic-Indic / Persian digits to Western `0-9`. Leaves other chars.
  static String toWestern(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      final char = String.fromCharCode(rune);
      final easternIndex = _eastern.indexOf(char);
      if (easternIndex >= 0) {
        buffer.write(easternIndex);
        continue;
      }
      final persianIndex = _persian.indexOf(char);
      if (persianIndex >= 0) {
        buffer.write(persianIndex);
        continue;
      }
      buffer.write(char);
    }
    return buffer.toString();
  }

  /// Western `0-9` → Arabic-Indic digits.
  static String toEastern(String input) {
    final buffer = StringBuffer();
    for (final unit in input.codeUnits) {
      if (unit >= 0x30 && unit <= 0x39) {
        buffer.write(_eastern[unit - 0x30]);
      } else {
        buffer.writeCharCode(unit);
      }
    }
    return buffer.toString();
  }

  /// Keeps only digit characters (any script), then returns Western digits.
  static String westernDigitsOnly(String input) {
    return toWestern(input).replaceAll(RegExp(r'\D'), '');
  }
}
