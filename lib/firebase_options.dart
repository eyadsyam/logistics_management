// Firebase configuration options generated from google-services.json and .env.
// For platforms that don't auto-discover config (e.g. Web), we pass these explicitly.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for each supported platform.
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
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for '
          '${defaultTargetPlatform.name} — run FlutterFire CLI to add support.',
        );
    }
  }

  // ── Android ──
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBu9YdcCx1vAuLt6ZvZHnyJMKbJm8c9xBs',
    appId: '1:638909307298:android:05c4b74b509f8eb1cf7afb',
    messagingSenderId: '638909307298',
    projectId: 'logistics-management-408b3',
    storageBucket: 'logistics-management-408b3.firebasestorage.app',
  );

  // ── Web ──
  // Uses the same project credentials. The appId below is the Web app ID.
  // If you haven't registered a Web app in Firebase Console yet, run:
  //   flutterfire configure
  // and it will auto-generate the correct appId for you.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBu9YdcCx1vAuLt6ZvZHnyJMKbJm8c9xBs',
    appId: '1:638909307298:web:05c4b74b509f8eb1cf7afb',
    messagingSenderId: '638909307298',
    projectId: 'logistics-management-408b3',
    storageBucket: 'logistics-management-408b3.firebasestorage.app',
    authDomain: 'logistics-management-408b3.firebaseapp.com',
  );

  // ── iOS (placeholder — update after registering iOS app in Firebase Console) ──
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBu9YdcCx1vAuLt6ZvZHnyJMKbJm8c9xBs',
    appId: '1:638909307298:ios:05c4b74b509f8eb1cf7afb',
    messagingSenderId: '638909307298',
    projectId: 'logistics-management-408b3',
    storageBucket: 'logistics-management-408b3.firebasestorage.app',
    iosBundleId: 'com.example.logisticsManagement',
  );
}
