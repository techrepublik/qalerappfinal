// Generated for this repo so `flutter analyze` / builds succeed.
// After you add the iOS app in Firebase Console (bundle id: com.alertify.joma),
// run: `dart pub global activate flutterfire_cli` then
// `flutterfire configure --project=qalert-79441` and replace this file, or edit
// the `ios` entry below using values from GoogleService-Info.plist.
//
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
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

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCe_NSy8P6rHiPwAaVxPfzDvJEjMFkqXV4',
    appId: '1:827333383227:web:2f0d8834ba3c1542ac781e',
    messagingSenderId: '827333383227',
    projectId: 'qalert-79441',
    authDomain: 'qalert-79441.firebaseapp.com',
    storageBucket: 'qalert-79441.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCe_NSy8P6rHiPwAaVxPfzDvJEjMFkqXV4',
    appId: '1:827333383227:android:0d876e2ab2f92f2dac781e',
    messagingSenderId: '827333383227',
    projectId: 'qalert-79441',
    storageBucket: 'qalert-79441.firebasestorage.app',
  );

  /// Replace `appId` (and apiKey if different) with values from Firebase after
  /// registering the iOS app. Add `GoogleService-Info.plist` to `ios/Runner/`.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCe_NSy8P6rHiPwAaVxPfzDvJEjMFkqXV4',
    // Placeholder — replace with real GOOGLE_APP_ID from GoogleService-Info.plist
    appId: '1:827333383227:ios:deadbeefdeadbeefdeadbeef',
    messagingSenderId: '827333383227',
    projectId: 'qalert-79441',
    storageBucket: 'qalert-79441.firebasestorage.app',
    iosBundleId: 'com.alertify.joma',
  );
}
