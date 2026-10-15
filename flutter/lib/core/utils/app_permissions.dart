import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:yalla_5roga/core/localization/l10n.dart';
import 'package:yalla_5roga/core/widgets/app_alert.dart';

enum AppPermissionResult {
  granted,
  denied,
  openedSettings,
}

class AppPermissions {
  const AppPermissions._();

  static var _notificationAskedThisSession = false;

  static Future<bool> get isNotificationGranted async {
    return Permission.notification.isGranted;
  }

  static Future<bool> get isLocationGranted async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// On app open: ask for notifications. Allow → system prompt, then phone
  /// app settings if still not granted.
  static Future<void> promptNotificationsOnLaunch(L10n l10n) async {
    if (_notificationAskedThisSession) return;
    if (await Permission.notification.isGranted) return;
    _notificationAskedThisSession = true;

    final allowed = await AppAlert.confirm(
      title: l10n.notificationAccessTitle,
      message: l10n.notificationAccessBody,
      confirmText: l10n.allow,
      cancelText: l10n.notNow,
    );
    if (!allowed) return;

    await _requestNotificationOrOpenSettings();
  }

  /// When picking a location. Allow → system prompt, then app settings if needed.
  static Future<AppPermissionResult> promptLocationAccess(L10n l10n) async {
    if (await isLocationGranted) return AppPermissionResult.granted;

    final allowed = await AppAlert.confirm(
      title: l10n.locationAccessTitle,
      message: l10n.locationAccessBody,
      confirmText: l10n.allowLocation,
      cancelText: l10n.notNow,
    );
    if (!allowed) return AppPermissionResult.denied;

    return _requestLocationOrOpenSettings();
  }

  /// Ask for contacts so member names can use device contact labels.
  static Future<AppPermissionResult> promptContactsAccess(L10n l10n) async {
    if (await Permission.contacts.isGranted) return AppPermissionResult.granted;

    final allowed = await AppAlert.confirm(
      title: l10n.contactsAccessTitle,
      message: l10n.contactsAccessBody,
      confirmText: l10n.allowContacts,
      cancelText: l10n.notNow,
    );
    if (!allowed) return AppPermissionResult.denied;

    var status = await Permission.contacts.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.contacts.request();
    }
    if (status.isGranted) return AppPermissionResult.granted;
    await openAppSettings();
    return AppPermissionResult.openedSettings;
  }

  /// When current-location needs permission that was previously denied.
  static Future<AppPermissionResult> ensureLocation(L10n l10n) async {
    if (await isLocationGranted) return AppPermissionResult.granted;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return AppPermissionResult.granted;
    }

    final open = await AppAlert.confirm(
      title: l10n.permissionNeededTitle,
      message: l10n.locationOpenSettingsBody,
      confirmText: l10n.openAppSettings,
      cancelText: l10n.notNow,
    );
    if (!open) return AppPermissionResult.denied;
    await openAppSettings();
    return AppPermissionResult.openedSettings;
  }

  static Future<AppPermissionResult> _requestNotificationOrOpenSettings() async {
    var status = await Permission.notification.status;
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.notification.request();
    }
    if (status.isGranted) return AppPermissionResult.granted;
    await openAppSettings();
    return AppPermissionResult.openedSettings;
  }

  static Future<AppPermissionResult> _requestLocationOrOpenSettings() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      return AppPermissionResult.granted;
    }
    await openAppSettings();
    return AppPermissionResult.openedSettings;
  }
}
