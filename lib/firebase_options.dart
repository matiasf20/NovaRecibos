// Archivo de configuración manual para NovaRecibos limpio
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
    return webAndGeneric; // 🚀 SOLUCIÓN: Evita el colapso en Safari/iOS Web
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q', 
    appId: '1:1085714774397:android:bc0d47392423a1bc',
    messagingSenderId: '1085714774397',
    projectId: 'novarecibos-86729',
    storageBucket: 'novarecibos-86729.appspot.com',
  );

  static const FirebaseOptions webAndGeneric = FirebaseOptions(
    apiKey: 'AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q',
    appId: '1:1085714774397:web:bc0d47392423a1bc',
    messagingSenderId: '1085714774397',
    projectId: 'novarecibos-86729',
    storageBucket: 'novarecibos-86729.appspot.com',
  );
}