import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:yalla_5roga/core/config/app_config.dart';

/// Platform Firebase options. Client identifiers come from [AppConfig]
/// (`--dart-define-from-file=.env`). Do not hardcode API keys here.
///
/// Native builds still need `google-services.json` / `GoogleService-Info.plist`.
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get android {
    final firebase = AppConfig.instance.firebase;
    return FirebaseOptions(
      apiKey: firebase.androidApiKey,
      appId: firebase.androidAppId,
      messagingSenderId: firebase.messagingSenderId,
      projectId: firebase.projectId,
      storageBucket: firebase.storageBucket,
    );
  }

  static FirebaseOptions get ios {
    final firebase = AppConfig.instance.firebase;
    return FirebaseOptions(
      apiKey: firebase.iosApiKey,
      appId: firebase.iosAppId,
      messagingSenderId: firebase.messagingSenderId,
      projectId: firebase.projectId,
      storageBucket: firebase.storageBucket,
      iosBundleId: firebase.iosBundleId,
      iosClientId: firebase.iosClientId,
    );
  }
}
