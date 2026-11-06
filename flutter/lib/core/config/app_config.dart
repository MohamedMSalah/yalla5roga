import 'package:flutter/foundation.dart';

/// Compile-time client configuration.
///
/// Values come from `--dart-define` / `--dart-define-from-file`, not from
/// runtime `.env` parsing. That is convenient for **non-secret** settings
/// (API host, timeouts, feature flags) and Firebase *client* identifiers.
/// It is **not** secure storage: anything compiled into the app can be
/// extracted from the binary.
///
/// Never put database passwords, JWT signing keys, service-account JSON,
/// or privileged backend tokens here. Those belong on the Node.js API.
/// Restrict Firebase client keys in Google Cloud and enable App Check.
class AppConfigException implements Exception {
  const AppConfigException(this.message);

  final String message;

  @override
  String toString() => 'AppConfigException: $message';
}

enum AppEnvironment {
  development,
  staging,
  production;

  static AppEnvironment parse(String value) {
    switch (value.trim().toLowerCase()) {
      case 'dev':
      case 'development':
        return AppEnvironment.development;
      case 'stg':
      case 'staging':
        return AppEnvironment.staging;
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      default:
        throw AppConfigException(
          'Unknown APP_ENV "$value". '
          'Use development, staging, or production.',
        );
    }
  }
}

/// Firebase *client* identifiers loaded from dart-define / `.env`.
///
/// These are not Admin SDK secrets, but they still must not be committed.
/// Restrict them by app + SHA/bundle ID in Google Cloud.
class FirebaseClientConfig {
  const FirebaseClientConfig({
    required this.androidApiKey,
    required this.iosApiKey,
    required this.androidAppId,
    required this.iosAppId,
    required this.messagingSenderId,
    required this.projectId,
    required this.storageBucket,
    required this.iosBundleId,
    required this.iosClientId,
    required this.webClientId,
  });

  static const testing = FirebaseClientConfig(
    androidApiKey: 'test-android-api-key',
    iosApiKey: 'test-ios-api-key',
    androidAppId: '1:0:android:test',
    iosAppId: '1:0:ios:test',
    messagingSenderId: '0',
    projectId: 'test-project',
    storageBucket: 'test-project.appspot.com',
    iosBundleId: 'com.example.yalla5roga',
    iosClientId: 'test-ios-client-id.apps.googleusercontent.com',
    webClientId: 'test-web-client-id.apps.googleusercontent.com',
  );

  final String androidApiKey;
  final String iosApiKey;
  final String androidAppId;
  final String iosAppId;
  final String messagingSenderId;
  final String projectId;
  final String storageBucket;
  final String iosBundleId;

  /// iOS OAuth client ID (`CLIENT_ID` in GoogleService-Info.plist).
  final String iosClientId;

  /// Web OAuth client ID used as Google Sign-In `serverClientId`.
  final String webClientId;

  void validate() {
    _require('FIREBASE_ANDROID_API_KEY', androidApiKey);
    _require('FIREBASE_IOS_API_KEY', iosApiKey);
    _require('FIREBASE_ANDROID_APP_ID', androidAppId);
    _require('FIREBASE_IOS_APP_ID', iosAppId);
    _require('FIREBASE_MESSAGING_SENDER_ID', messagingSenderId);
    _require('FIREBASE_PROJECT_ID', projectId);
    _require('FIREBASE_STORAGE_BUCKET', storageBucket);
    _require('FIREBASE_IOS_BUNDLE_ID', iosBundleId);
    _require('FIREBASE_IOS_CLIENT_ID', iosClientId);
    _require('FIREBASE_WEB_CLIENT_ID', webClientId);
  }

  static void _require(String name, String value) {
    if (value.trim().isEmpty) {
      throw AppConfigException(
        '$name is required. Set it in .env and pass '
        '--dart-define-from-file=.env.',
      );
    }
  }
}

class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.nominatimHost,
    required this.osmTileUrlTemplate,
    required this.downloadUrl,
    required this.firebase,
  });

  static const String defaultDevelopmentApiBaseUrl = 'http://10.0.2.2:3000';
  static const String defaultNominatimHost = 'nominatim.openstreetmap.org';
  static const String defaultOsmTileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String defaultDownloadUrl = 'https://yalla5roga.com';
  static const int defaultTimeoutMs = 30000;

  final AppEnvironment environment;
  final String apiBaseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final String nominatimHost;
  final String osmTileUrlTemplate;
  final String downloadUrl;
  final FirebaseClientConfig firebase;

  static AppConfig? _instance;

  /// Bound configuration. Throws if [initialize] has not run.
  static AppConfig get instance {
    final current = _instance;
    if (current == null) {
      throw const AppConfigException(
        'AppConfig has not been initialized. '
        'Call AppConfig.initializeFromEnvironment() at startup.',
      );
    }
    return current;
  }

  static bool get isInitialized => _instance != null;

  /// Safe dummy config for widget/unit tests.
  factory AppConfig.testing({
    AppEnvironment environment = AppEnvironment.development,
    String apiBaseUrl = defaultDevelopmentApiBaseUrl,
    Duration connectTimeout = const Duration(milliseconds: defaultTimeoutMs),
    Duration receiveTimeout = const Duration(milliseconds: defaultTimeoutMs),
    String nominatimHost = defaultNominatimHost,
    String osmTileUrlTemplate = defaultOsmTileUrlTemplate,
    String downloadUrl = defaultDownloadUrl,
    FirebaseClientConfig firebase = FirebaseClientConfig.testing,
  }) {
    return AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      connectTimeout: connectTimeout,
      receiveTimeout: receiveTimeout,
      nominatimHost: nominatimHost,
      osmTileUrlTemplate: osmTileUrlTemplate,
      downloadUrl: downloadUrl,
      firebase: firebase,
    );
  }

  /// Reads `--dart-define` / `--dart-define-from-file` values.
  factory AppConfig.fromEnvironment({bool debugMode = kDebugMode}) {
    const rawEnv = String.fromEnvironment('APP_ENV');
    const rawApiBaseUrl = String.fromEnvironment('API_BASE_URL');
    const connectTimeoutMs = int.fromEnvironment(
      'API_CONNECT_TIMEOUT_MS',
      defaultValue: defaultTimeoutMs,
    );
    const receiveTimeoutMs = int.fromEnvironment(
      'API_RECEIVE_TIMEOUT_MS',
      defaultValue: defaultTimeoutMs,
    );
    const rawNominatimHost = String.fromEnvironment('NOMINATIM_HOST');
    const rawOsmTileUrl = String.fromEnvironment('OSM_TILE_URL');
    const rawDownloadUrl = String.fromEnvironment('APP_DOWNLOAD_URL');
    const firebaseAndroidApiKey = String.fromEnvironment(
      'FIREBASE_ANDROID_API_KEY',
    );
    const firebaseIosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
    const firebaseAndroidAppId = String.fromEnvironment(
      'FIREBASE_ANDROID_APP_ID',
    );
    const firebaseIosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
    const firebaseMessagingSenderId = String.fromEnvironment(
      'FIREBASE_MESSAGING_SENDER_ID',
    );
    const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    const firebaseStorageBucket = String.fromEnvironment(
      'FIREBASE_STORAGE_BUCKET',
    );
    const firebaseIosBundleId = String.fromEnvironment(
      'FIREBASE_IOS_BUNDLE_ID',
    );
    const firebaseIosClientId = String.fromEnvironment(
      'FIREBASE_IOS_CLIENT_ID',
    );
    const firebaseWebClientId = String.fromEnvironment(
      'FIREBASE_WEB_CLIENT_ID',
    );

    if (rawEnv.isEmpty && !debugMode) {
      throw const AppConfigException(
        'APP_ENV is required outside debug builds. '
        'Pass --dart-define-from-file=.env or --dart-define=APP_ENV=production.',
      );
    }

    final environment = AppEnvironment.parse(
      rawEnv.isEmpty ? 'development' : rawEnv,
    );

    var apiBaseUrl = rawApiBaseUrl.trim();
    if (apiBaseUrl.isEmpty &&
        debugMode &&
        environment == AppEnvironment.development) {
      apiBaseUrl = defaultDevelopmentApiBaseUrl;
    }

    final config = AppConfig(
      environment: environment,
      apiBaseUrl: apiBaseUrl,
      connectTimeout: Duration(milliseconds: connectTimeoutMs),
      receiveTimeout: Duration(milliseconds: receiveTimeoutMs),
      nominatimHost: rawNominatimHost.trim().isEmpty
          ? defaultNominatimHost
          : rawNominatimHost.trim(),
      osmTileUrlTemplate: rawOsmTileUrl.trim().isEmpty
          ? defaultOsmTileUrlTemplate
          : rawOsmTileUrl.trim(),
      downloadUrl: rawDownloadUrl.trim().isEmpty
          ? defaultDownloadUrl
          : rawDownloadUrl.trim(),
      firebase: FirebaseClientConfig(
        androidApiKey: firebaseAndroidApiKey.trim(),
        iosApiKey: firebaseIosApiKey.trim(),
        androidAppId: firebaseAndroidAppId.trim(),
        iosAppId: firebaseIosAppId.trim(),
        messagingSenderId: firebaseMessagingSenderId.trim(),
        projectId: firebaseProjectId.trim(),
        storageBucket: firebaseStorageBucket.trim(),
        iosBundleId: firebaseIosBundleId.trim(),
        iosClientId: firebaseIosClientId.trim(),
        webClientId: firebaseWebClientId.trim(),
      ),
    );
    config.validate();
    return config;
  }

  /// Validates and binds [config] as the process-wide instance.
  static void initialize(AppConfig config) {
    config.validate();
    _instance = config;
    _logSummary(config);
  }

  static void initializeFromEnvironment({bool debugMode = kDebugMode}) {
    initialize(AppConfig.fromEnvironment(debugMode: debugMode));
  }

  @visibleForTesting
  static void reset() => _instance = null;

  void validate() {
    if (connectTimeout <= Duration.zero || receiveTimeout <= Duration.zero) {
      throw const AppConfigException(
        'API_CONNECT_TIMEOUT_MS and API_RECEIVE_TIMEOUT_MS must be > 0.',
      );
    }
    if (connectTimeout > const Duration(minutes: 2) ||
        receiveTimeout > const Duration(minutes: 2)) {
      throw const AppConfigException('API timeouts must be 120000 ms or less.');
    }

    final url = apiBaseUrl.trim();
    if (url.isEmpty) {
      throw const AppConfigException(
        'API_BASE_URL is required. '
        'Set it in .env and pass --dart-define-from-file=.env.',
      );
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const AppConfigException(
        'API_BASE_URL must be an absolute URL with a host, '
        'for example http://10.0.2.2:3000.',
      );
    }
    if (uri.userInfo.isNotEmpty) {
      throw const AppConfigException(
        'API_BASE_URL must not include a username or password. '
        'Privileged credentials belong on the backend only.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      throw AppConfigException(
        'API_BASE_URL scheme "${uri.scheme}" is not supported. Use http or https.',
      );
    }

    if (nominatimHost.trim().isEmpty) {
      throw const AppConfigException('NOMINATIM_HOST must not be empty.');
    }
    if (osmTileUrlTemplate.trim().isEmpty) {
      throw const AppConfigException('OSM_TILE_URL must not be empty.');
    }
    if (downloadUrl.trim().isEmpty) {
      throw const AppConfigException('APP_DOWNLOAD_URL must not be empty.');
    }

    firebase.validate();

    if (environment == AppEnvironment.production) {
      if (uri.scheme != 'https') {
        throw const AppConfigException(
          'Production API_BASE_URL must use https.',
        );
      }
      if (_isLoopbackHost(uri.host)) {
        throw const AppConfigException(
          'Production API_BASE_URL must not point at a loopback or emulator host.',
        );
      }
    }
  }

  static bool _isLoopbackHost(String host) {
    switch (host.toLowerCase()) {
      case 'localhost':
      case '127.0.0.1':
      case '::1':
      case '0.0.0.0':
      case '10.0.2.2':
        return true;
      default:
        return false;
    }
  }

  static void _logSummary(AppConfig config) {
    if (!kDebugMode) return;
    final host = Uri.tryParse(config.apiBaseUrl)?.host ?? '(invalid)';
    debugPrint(
      '[AppConfig] env=${config.environment.name} '
      'apiHost=$host firebaseProject=${config.firebase.projectId}',
    );
  }

  @override
  String toString() {
    final host = Uri.tryParse(apiBaseUrl)?.host ?? '(invalid)';
    return 'AppConfig(${environment.name}, '
        'host=$host, firebaseProject=${firebase.projectId})';
  }
}
