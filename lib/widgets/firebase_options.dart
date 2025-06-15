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
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDWf0hqpl7IaI8tnMZ_Pff3Qot7uUCWoEo',
    appId: '1:86382351062:web:your-web-app-id',
    messagingSenderId: '86382351062',
    projectId: 'finity-73202',
    authDomain: 'finity-73202.firebaseapp.com',
    storageBucket: 'finity-73202.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDWf0hqpl7IaI8tnMZ_Pff3Qot7uUCWoEo',
    appId: '1:86382351062:android:1f86a51fc38bf9f2a4ef77',
    messagingSenderId: '86382351062',
    projectId: 'finity-73202',
    storageBucket: 'finity-73202.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDWf0hqpl7IaI8tnMZ_Pff3Qot7uUCWoEo',
    appId: '1:86382351062:ios:your-ios-app-id',
    messagingSenderId: '86382351062',
    projectId: 'finity-73202',
    storageBucket: 'finity-73202.firebasestorage.app',
    iosBundleId: 'com.app.finity',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDWf0hqpl7IaI8tnMZ_Pff3Qot7uUCWoEo',
    appId: '1:86382351062:macos:your-macos-app-id',
    messagingSenderId: '86382351062',
    projectId: 'finity-73202',
    storageBucket: 'finity-73202.firebasestorage.app',
    iosBundleId: 'com.app.finity',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDWf0hqpl7IaI8tnMZ_Pff3Qot7uUCWoEo',
    appId: '1:86382351062:windows:your-windows-app-id',
    messagingSenderId: '86382351062',
    projectId: 'finity-73202',
    authDomain: 'finity-73202.firebaseapp.com',
    storageBucket: 'finity-73202.firebasestorage.app',
  );
}
