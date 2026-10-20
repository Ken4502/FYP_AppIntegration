import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
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
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC0wZa7MPnfuXQW-7mPUklBWFVhJoHLo6Y',
    appId: '1:792382083515:web:urbangreenfyp',
    messagingSenderId: '792382083515',
    projectId: 'urbangreenfyp',
    authDomain: 'urbangreenfyp.firebaseapp.com',
    storageBucket: 'urbangreenfyp.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC0wZa7MPnfuXQW-7mPUklBWFVhJoHLo6Y',
    appId: '1:792382083515:android:63e147e516bd24b887349e',
    messagingSenderId: '792382083515',
    projectId: 'urbangreenfyp',
    storageBucket: 'urbangreenfyp.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC0wZa7MPnfuXQW-7mPUklBWFVhJoHLo6Y',
    appId: '1:792382083515:ios:urbangreenfyp',
    messagingSenderId: '792382083515',
    projectId: 'urbangreenfyp',
    storageBucket: 'urbangreenfyp.firebasestorage.app',
    iosBundleId: 'urban.green',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyC0wZa7MPnfuXQW-7mPUklBWFVhJoHLo6Y',
    appId: '1:792382083515:ios:urbangreenfyp',
    messagingSenderId: '792382083515',
    projectId: 'urbangreenfyp',
    storageBucket: 'urbangreenfyp.firebasestorage.app',
    iosBundleId: 'urban.green',
  );
}
