// Archivo de configuración manual para NovaRecibos
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return webAndGeneric;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return android;
    }
    return webAndGeneric;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyAEJPiFMZ3FT43U33imHnAx0biy8Fn7N6E",
    appId: '1:1085714774397:android:bc0d47392423a1bc',
    messagingSenderId: '1085714774397',
    projectId: 'novarecibos-86729',
    storageBucket: 'novarecibos-86729.appspot.com',
  );

  static const FirebaseOptions webAndGeneric = FirebaseOptions(
    apiKey: "AIzaSyAEJPiFMZ3FT43U33imHnAx0biy8Fn7N6E",
    appId: '1:897930442604:web:633be00de81bb56f61a549',
    messagingSenderId: '897930442604',
    projectId: 'novarecibos-86729',
    authDomain: 'novarecibos-86729.firebaseapp.com',
    storageBucket: 'novarecibos-86729.firebasestorage.app',
  );
}