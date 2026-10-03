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
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyADPbEgRsu8EgCSbULsmtxmcpcgGJacia8',
    appId: '1:18953853541:web:25558e9ead8d086ed2448c',
    messagingSenderId: '18953853541',
    projectId: 'sheride-1',
    authDomain: 'sheride-1.firebaseapp.com',
    databaseURL: 'https://sheride-1-default-rtdb.firebaseio.com',
    storageBucket: 'sheride-1.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBwoAzTXR7itiSSo9RDSouqXIYC0ljeJHM',
    appId: '1:18953853541:android:d28efef9cd5b6765d2448c',
    messagingSenderId: '18953853541',
    projectId: 'sheride-1',
    databaseURL: 'https://sheride-1-default-rtdb.firebaseio.com',
    storageBucket: 'sheride-1.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBwoAzTXR7itiSSo9RDSouqXIYC0ljeJHM',
    appId: '1:18953853541:ios:d28efef9cd5b6765d2448c',
    messagingSenderId: '18953853541',
    projectId: 'sheride-1',
    databaseURL: 'https://sheride-1-default-rtdb.firebaseio.com',
    storageBucket: 'sheride-1.firebasestorage.app',
  );
}
