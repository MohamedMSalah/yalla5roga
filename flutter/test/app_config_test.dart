import 'package:flutter_test/flutter_test.dart';
import 'package:yalla_5roga/core/config/app_config.dart';

void main() {
  tearDown(() {
    AppConfig.initialize(AppConfig.testing());
  });

  AppConfig productionConfig({
    String apiBaseUrl = 'https://api.example.com',
  }) {
    return AppConfig.testing(
      environment: AppEnvironment.production,
      apiBaseUrl: apiBaseUrl,
    );
  }

  test('debug fromEnvironment requires Firebase client options', () {
    const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
    if (projectId.isNotEmpty) {
      final config = AppConfig.fromEnvironment(debugMode: true);
      expect(config.environment, AppEnvironment.development);
      expect(config.firebase.projectId, isNotEmpty);
      return;
    }
    expect(
      () => AppConfig.fromEnvironment(debugMode: true),
      throwsA(
        isA<AppConfigException>().having(
          (error) => error.message,
          'message',
          contains('FIREBASE'),
        ),
      ),
    );
  });

  test('release fromEnvironment requires APP_ENV when unset', () {
    const rawEnv = String.fromEnvironment('APP_ENV');
    if (rawEnv.isNotEmpty) {
      return;
    }
    expect(
      () => AppConfig.fromEnvironment(debugMode: false),
      throwsA(
        isA<AppConfigException>().having(
          (error) => error.message,
          'message',
          contains('APP_ENV is required'),
        ),
      ),
    );
  });

  test('initialize binds instance for the rest of the app', () {
    AppConfig.reset();
    expect(() => AppConfig.instance, throwsA(isA<AppConfigException>()));

    final config = AppConfig.testing();
    AppConfig.initialize(config);
    expect(AppConfig.instance.apiBaseUrl, config.apiBaseUrl);
    expect(AppConfig.instance.firebase.projectId, 'test-project');
  });

  test('testing() is valid configuration', () {
    expect(() => AppConfig.testing(), returnsNormally);
    AppConfig.testing().validate();
  });

  test('production rejects http and loopback hosts', () {
    expect(
      () => productionConfig(apiBaseUrl: 'http://api.example.com').validate(),
      throwsA(isA<AppConfigException>()),
    );
    expect(
      () => productionConfig(apiBaseUrl: 'https://10.0.2.2:3000').validate(),
      throwsA(isA<AppConfigException>()),
    );
    expect(
      () => productionConfig(apiBaseUrl: 'https://localhost:3000').validate(),
      throwsA(isA<AppConfigException>()),
    );
  });

  test('production accepts https public hosts', () {
    expect(productionConfig().validate, returnsNormally);
  });

  test('rejects embedded credentials in API_BASE_URL', () {
    final config = AppConfig.testing(
      apiBaseUrl: 'https://user:password@api.example.com',
    );
    expect(
      () => config.validate(),
      throwsA(
        isA<AppConfigException>().having(
          (error) => error.message,
          'message',
          contains('username or password'),
        ),
      ),
    );
  });

  test('rejects empty and invalid API_BASE_URL', () {
    expect(
      () => AppConfig.testing(apiBaseUrl: '').validate(),
      throwsA(isA<AppConfigException>()),
    );
    expect(
      () => AppConfig.testing(apiBaseUrl: 'not-a-url').validate(),
      throwsA(isA<AppConfigException>()),
    );
  });

  test('rejects missing Google OAuth client IDs', () {
    expect(
      () => AppConfig.testing(
        firebase: const FirebaseClientConfig(
          androidApiKey: 'test-android-api-key',
          iosApiKey: 'test-ios-api-key',
          androidAppId: '1:0:android:test',
          iosAppId: '1:0:ios:test',
          messagingSenderId: '0',
          projectId: 'test-project',
          storageBucket: 'test-project.appspot.com',
          iosBundleId: 'com.example.yalla5roga',
          iosClientId: '',
          webClientId: 'test-web-client-id.apps.googleusercontent.com',
        ),
      ).validate(),
      throwsA(
        isA<AppConfigException>().having(
          (error) => error.message,
          'message',
          contains('FIREBASE_IOS_CLIENT_ID'),
        ),
      ),
    );
  });

  test('rejects missing Firebase client options', () {
    expect(
      () => AppConfig.testing(
        firebase: const FirebaseClientConfig(
          androidApiKey: '',
          iosApiKey: 'test-ios-api-key',
          androidAppId: '1:0:android:test',
          iosAppId: '1:0:ios:test',
          messagingSenderId: '0',
          projectId: 'test-project',
          storageBucket: 'test-project.appspot.com',
          iosBundleId: 'com.example.yalla5roga',
          iosClientId: 'test-ios-client-id.apps.googleusercontent.com',
          webClientId: 'test-web-client-id.apps.googleusercontent.com',
        ),
      ).validate(),
      throwsA(
        isA<AppConfigException>().having(
          (error) => error.message,
          'message',
          contains('FIREBASE_ANDROID_API_KEY'),
        ),
      ),
    );
  });

  test('staging allows http for private hosts', () {
    final config = AppConfig.testing(
      environment: AppEnvironment.staging,
      apiBaseUrl: 'http://192.168.1.10:3000',
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    );
    expect(config.validate, returnsNormally);
  });

  test('toString does not include credentials or Firebase API keys', () {
    final summary = AppConfig.testing(
      apiBaseUrl: 'http://10.0.2.2:3000/secret-path',
      firebase: const FirebaseClientConfig(
        androidApiKey: 'AIzaSySECRETANDROIDKEY',
        iosApiKey: 'AIzaSySECRETIOSKEY',
        androidAppId: '1:0:android:test',
        iosAppId: '1:0:ios:test',
        messagingSenderId: '0',
        projectId: 'test-project',
        storageBucket: 'test-project.appspot.com',
        iosBundleId: 'com.example.yalla5roga',
        iosClientId: 'test-ios-client-id.apps.googleusercontent.com',
        webClientId: 'test-web-client-id.apps.googleusercontent.com',
      ),
    ).toString();
    expect(summary, contains('development'));
    expect(summary, contains('10.0.2.2'));
    expect(summary, contains('test-project'));
    expect(summary, isNot(contains('secret-path')));
    expect(summary, isNot(contains('password')));
    expect(summary, isNot(contains('AIza')));
    expect(summary, isNot(contains('SECRET')));
  });

  test('AppEnvironment.parse accepts aliases and rejects unknown', () {
    expect(AppEnvironment.parse('dev'), AppEnvironment.development);
    expect(AppEnvironment.parse('STG'), AppEnvironment.staging);
    expect(AppEnvironment.parse('prod'), AppEnvironment.production);
    expect(
      () => AppEnvironment.parse('qa'),
      throwsA(isA<AppConfigException>()),
    );
  });
}
