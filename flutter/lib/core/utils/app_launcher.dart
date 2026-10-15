import 'package:url_launcher/url_launcher.dart';

class AppLauncher {
  const AppLauncher._();

  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openMaps({
    double? latitude,
    double? longitude,
    String? query,
  }) async {
    try {
      if (latitude != null && longitude != null) {
        final label = (query == null || query.isEmpty) ? '$latitude,$longitude' : query;
        final geo = Uri.parse(
          'geo:$latitude,$longitude?q=${Uri.encodeComponent('$latitude,$longitude($label)')}',
        );
        if (await canLaunchUrl(geo)) {
          return await launchUrl(geo, mode: LaunchMode.externalApplication);
        }
        return await launchUrl(
          Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': '$latitude,$longitude'}),
          mode: LaunchMode.externalApplication,
        );
      }
      if (query != null && query.trim().isNotEmpty) {
        return await launchUrl(
          Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query.trim()}),
          mode: LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> shareOnWhatsApp(String message) async {
    try {
      final native = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
      if (await canLaunchUrl(native)) {
        return await launchUrl(native, mode: LaunchMode.externalApplication);
      }
      return await launchUrl(
        Uri.https('wa.me', '/', {'text': message}),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
