import 'package:flutter_contacts/flutter_contacts.dart' hide PermissionStatus;
import 'package:permission_handler/permission_handler.dart';
import 'package:yalla_5roga/core/utils/digit_utils.dart';
import 'package:yalla_5roga/core/utils/validators.dart';
import 'package:yalla_5roga/features/groups/domain/entities/group_member.dart';

/// Resolves a display name for group members:
/// device contact name → registered profile name → phone.
class MemberDisplayName {
  const MemberDisplayName._();

  static final Map<String, String> _contactNamesByPhone = {};
  static var _loaded = false;
  static var _permissionDenied = false;
  static GroupMember? Function(String phone)? memberByPhoneLookup;

  static bool get hasContactCache => _loaded && !_permissionDenied;

  static Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    if (_permissionDenied && !force) return;

    try {
      var status = await Permission.contacts.status;
      if (!status.isGranted && !status.isLimited) {
        status = await Permission.contacts.request();
      }
      if (!status.isGranted && !status.isLimited) {
        _permissionDenied = true;
        _loaded = true;
        _contactNamesByPhone.clear();
        return;
      }

      _permissionDenied = false;
      final contacts = await FlutterContacts.getAll(
        properties: {ContactProperty.phone, ContactProperty.name},
      );
      _contactNamesByPhone.clear();
      for (final contact in contacts) {
        final display = (contact.displayName ?? '').trim();
        if (display.isEmpty) continue;
        for (final phone in contact.phones) {
          final number = (phone.normalizedNumber ?? phone.number).trim();
          if (!Validators.isValidEgyptianPhone(number)) continue;
          _contactNamesByPhone[Validators.normalizePhone(number)] = display;
        }
      }
      _loaded = true;
    } catch (_) {
      _permissionDenied = true;
      _loaded = true;
      _contactNamesByPhone.clear();
    }
  }

  static void clearCache() {
    _contactNamesByPhone.clear();
    _loaded = false;
    _permissionDenied = false;
  }

  static String resolve(GroupMember member, {String? fallbackPhone}) {
    final phone = member.phone ?? fallbackPhone;
    if (phone != null &&
        phone.isNotEmpty &&
        Validators.isValidEgyptianPhone(phone)) {
      final normalized = Validators.normalizePhone(phone);
      final contactName = _contactNamesByPhone[normalized];
      if (contactName != null && contactName.isNotEmpty) return contactName;
    }

    final registered = member.name.trim();
    if (registered.isNotEmpty &&
        registered != phone &&
        !_looksLikePhone(registered)) {
      return registered;
    }

    if (phone != null && phone.isNotEmpty) return phone;
    if (registered.isNotEmpty) return registered;
    return member.id;
  }

  static String resolvePhone(String phone, {String? registeredName}) {
    if (Validators.isValidEgyptianPhone(phone)) {
      final normalized = Validators.normalizePhone(phone);
      final contactName = _contactNamesByPhone[normalized];
      if (contactName != null && contactName.isNotEmpty) return contactName;
      final known = memberByPhoneLookup?.call(normalized);
      if (known != null) return resolve(known);
    }
    final name = registeredName?.trim();
    if (name != null && name.isNotEmpty && !_looksLikePhone(name)) return name;
    return phone;
  }

  static bool _looksLikePhone(String value) {
    return DigitUtils.westernDigitsOnly(value).length >= 10;
  }
}
