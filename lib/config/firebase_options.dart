/// Placeholder for Firebase configuration.
/// 
/// This file should contain the FirebaseOptions class for each platform.
/// When Firebase is configured, replace this with actual Firebase setup.
/// 
/// To set up Firebase:
/// 1. Create a Firebase project at https://console.firebase.google.com
/// 2. Add iOS and Android apps
/// 3. Download configuration files
/// 4. Run `flutterfire configure`
/// 5. Replace this file with the generated firebase_options.dart

import 'package:flutter/foundation.dart';

/// Default Firebase options for each platform.
///
/// These are placeholder values. Replace with actual Firebase configuration.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'DefaultFirebaseOptions have not been configured for this platform.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: '1:123456789:web:abcdef123456',
    messagingSenderId: '123456789',
    projectId: 'signsync-app',
    authDomain: 'signsync-app.firebaseapp.com',
    storageBucket: 'signsync-app.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: '1:123456789:android:abcdef123456',
    messagingSenderId: '123456789',
    projectId: 'signsync-app',
    authDomain: 'signsync-app.firebaseapp.com',
    storageBucket: 'signsync-app.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: '1:123456789:ios:abcdef123456',
    messagingSenderId: '123456789',
    projectId: 'signsync-app',
    authDomain: 'signsync-app.firebaseapp.com',
    storageBucket: 'signsync-app.appspot.com',
    iosClientId: '123456789-abc123.apps.googleusercontent.com',
    iosBundleId: 'com.signsync.app',
  );
}

import 'package:firebase_core/firebase_core.dart';
