// Firebase options for push notifications. The values are not in the repo:
// they come from the build, via `--dart-define-from-file=env/firebase.json`
// (git-ignored; copy env/firebase.example.json and fill it from the Firebase
// console). Without them Firebase stays off and the app runs without push.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const _senderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _storageBucket = String.fromEnvironment(
    'FIREBASE_STORAGE_BUCKET',
  );
  static const _androidApiKey = String.fromEnvironment(
    'FIREBASE_ANDROID_API_KEY',
  );
  static const _androidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const _iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  /// Options for this platform, or `null` where they weren't provided at
  /// build time (or on web/desktop) — the app then runs without Firebase.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb || _projectId.isEmpty) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android when _androidApiKey.isNotEmpty => FirebaseOptions(
        apiKey: _androidApiKey,
        appId: _androidAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
      ),
      TargetPlatform.iOS when _iosApiKey.isNotEmpty => FirebaseOptions(
        apiKey: _iosApiKey,
        appId: _iosAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket,
        iosBundleId: _iosBundleId,
      ),
      _ => null,
    };
  }
}
