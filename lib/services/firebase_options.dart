import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Replace with the values from your Firebase project console:
///   Project Settings > General > Your apps > SDK setup and configuration
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_ANDROID_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'scales-karaoke',
    storageBucket: 'scales-karaoke.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'scales-karaoke',
    storageBucket: 'scales-karaoke.appspot.com',
    iosBundleId: 'com.example.scalesMobile',
  );
}
