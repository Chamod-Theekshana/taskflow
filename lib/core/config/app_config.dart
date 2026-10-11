import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Build-time configuration, passed with `--dart-define` (or
/// `--dart-define-from-file=config/dev.json`, see config/example.json).
///
/// Nothing secret lives here: Firebase client keys are public identifiers.
abstract final class AppConfig {
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Base URL of the TaskFlow API, including `/api/v1`.
  ///
  /// Defaults to the local development server: `10.0.2.2` is the host
  /// machine as seen from the Android emulator.
  static String get apiBaseUrl {
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  // Firebase (push notifications). Leave empty to run without push.
  static const _firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );
  static const _firebaseSenderId = String.fromEnvironment(
    'FIREBASE_MESSAGING_SENDER_ID',
  );
  static const _firebaseAndroidAppId = String.fromEnvironment(
    'FIREBASE_ANDROID_APP_ID',
  );
  static const _firebaseIosAppId = String.fromEnvironment(
    'FIREBASE_IOS_APP_ID',
  );
  static const _iosBundleId = String.fromEnvironment(
    'IOS_BUNDLE_ID',
    defaultValue: 'com.taskflow.taskflow',
  );

  static String get _firebaseAppId =>
      defaultTargetPlatform == TargetPlatform.iOS
      ? _firebaseIosAppId
      : _firebaseAndroidAppId;

  /// Firebase options for this platform, or null when push isn't set up.
  static FirebaseOptions? get firebaseOptions {
    if (_firebaseApiKey.isEmpty ||
        _firebaseProjectId.isEmpty ||
        _firebaseSenderId.isEmpty ||
        _firebaseAppId.isEmpty) {
      return null;
    }
    return FirebaseOptions(
      apiKey: _firebaseApiKey,
      appId: _firebaseAppId,
      messagingSenderId: _firebaseSenderId,
      projectId: _firebaseProjectId,
      iosBundleId: _iosBundleId,
    );
  }
}
