// lib/firebase_options.dart

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

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
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDX_fhBTQmwm-KP8Qu2gfwFQylGuaEm4VA',
    authDomain: 'eng-system.firebaseapp.com',
    projectId: 'eng-system',
    storageBucket: 'eng-system.firebasestorage.app',
    messagingSenderId: '526461382833',
    appId: '1:526461382833:web:46090faa13de2d4b30f290',
    measurementId: 'G-NMMTY5PN4Y',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDRvznjDBdA83VNWzmbC2VbU-0UGuYyRCk', // MODIFIED - from google-services.json
    authDomain: 'eng-system.firebaseapp.com',
    projectId: 'eng-system',
    storageBucket: 'eng-system.firebasestorage.app',
    messagingSenderId: '526461382833',
    appId: '1:526461382833:android:5a049565fbb06e9330f290', // MODIFIED - from google-services.json
    measurementId: 'G-NMMTY5PN4Y', // Kept your existing measurementId
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDX_fhBTQmwm-KP8Qu2gfwFQylGuaEm4VA', // WARNING: This might be incorrect for native iOS
    authDomain: 'eng-system.firebaseapp.com',
    projectId: 'eng-system',
    storageBucket: 'eng-system.firebasestorage.app',
    messagingSenderId: '526461382833',
    appId: '1:526461382833:web:46090faa13de2d4b30f290', // WARNING: This is a web App ID, likely incorrect for native iOS
    measurementId: 'G-NMMTY5PN4Y',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDX_fhBTQmwm-KP8Qu2gfwFQylGuaEm4VA', // WARNING: This might be incorrect for native macOS
    authDomain: 'eng-system.firebaseapp.com',
    projectId: 'eng-system',
    storageBucket: 'eng-system.firebasestorage.app',
    messagingSenderId: '526461382833',
    appId: '1:526461382833:web:46090faa13de2d4b30f290', // WARNING: This is a web App ID, likely incorrect for native macOS
    measurementId: 'G-NMMTY5PN4Y',
  );
}