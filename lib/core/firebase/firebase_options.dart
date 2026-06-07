import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase config for Flavor Flow (project: resto-a0d9a).
///
/// For production Windows builds, add a **Windows** app in Firebase Console
/// and replace [windows].appId with the Windows app id from that registration.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCVEzgrDcjZOiv7R4QK3IH3kZBfq_Dh1Vo',
    appId: '1:799838711875:web:0fae0ecb393db8cef624f6',
    messagingSenderId: '799838711875',
    projectId: 'resto-a0d9a',
    authDomain: 'resto-a0d9a.firebaseapp.com',
    storageBucket: 'resto-a0d9a.firebasestorage.app',
    measurementId: 'G-ZPDSQ8MNJD',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBMMra2aSYq5Iy_SJNaGN4Jzw2pNZZ0pyY',
    appId: '1:799838711875:android:f3fed8462194742cf624f6',
    messagingSenderId: '799838711875',
    projectId: 'resto-a0d9a',
    storageBucket: 'resto-a0d9a.firebasestorage.app',
  );

  /// Uses web app id until a dedicated Windows app is registered in Firebase.
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCVEzgrDcjZOiv7R4QK3IH3kZBfq_Dh1Vo',
    appId: '1:799838711875:web:0fae0ecb393db8cef624f6',
    messagingSenderId: '799838711875',
    projectId: 'resto-a0d9a',
    authDomain: 'resto-a0d9a.firebaseapp.com',
    storageBucket: 'resto-a0d9a.firebasestorage.app',
  );
}
