// مفاتيح مشروع FAWORI - من Firebase console
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'منصات الجوال لم تسجل بعد في Firebase console.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyByCGMqCQ7Z-SW5hf3KqIDF47APwDWXPj8',
    appId: '1:710287285597:web:e1b6d342b2ffcc56d75cb4',
    messagingSenderId: '710287285597',
    projectId: 'fawori-abd13',
    authDomain: 'fawori-abd13.firebaseapp.com',
    storageBucket: 'fawori-abd13.firebasestorage.app',
    measurementId: 'G-579NLMJMX0',
  );
}
