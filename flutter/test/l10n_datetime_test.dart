import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  });

  test('formats outing dates in English and Arabic', () {
    final at = DateTime(2026, 10, 26, 20, 0);
    final en = const L10n(Locale('en'));
    final ar = const L10n(Locale('ar'));

    expect(en.formatDate(at).toUpperCase(), contains('OCT'));
    expect(en.formatTime(at).toUpperCase(), contains('PM'));

    expect(ar.formatDate(at), contains('أكتوبر'));
    expect(ar.formatTime(at), contains('م'));
    expect(ar.formatTime(at), contains('٨'));
  });

  test('parses stored English clock strings into the active locale', () {
    final ar = const L10n(Locale('ar'));
    expect(ar.formatClock('8:00 PM'), contains('م'));
    expect(ar.formatStoredTime(null, '5:00 PM'), contains('٥'));
  });
}
