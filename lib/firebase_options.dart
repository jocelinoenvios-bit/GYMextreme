// Configuracao real do Firebase (projeto gymextreme-42c98), gerada com a
// FlutterFire CLI:
//   flutterfire configure --project=gymextreme-42c98 --platforms=android,web
//
// Se o projeto Firebase mudar (novo app Web/Android, rotacao de chave),
// rode o comando acima de novo pra atualizar este arquivo.
//
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Opcoes do Firebase por plataforma, no mesmo formato gerado pela
/// FlutterFire CLI. Use [DefaultFirebaseOptions.currentPlatform] para
/// inicializar o Firebase.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions ainda nao foi configurado para a '
          'plataforma ${defaultTargetPlatform.name}. Este modulo cobre '
          'apenas Android e Web (o iOS roda como PWA no navegador).',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAAARv_nA7OOLtJla6D0taHmXLd5KQ_1m0',
    appId: '1:258628817510:web:3b21a84833d90a6fb953a7',
    messagingSenderId: '258628817510',
    projectId: 'gymextreme-42c98',
    authDomain: 'gymextreme-42c98.firebaseapp.com',
    storageBucket: 'gymextreme-42c98.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDGG6RU-7LOl0Q9ePfj-xSGeKRvUdOBcw0',
    appId: '1:258628817510:android:6b97eb8c5b6b326ab953a7',
    messagingSenderId: '258628817510',
    projectId: 'gymextreme-42c98',
    storageBucket: 'gymextreme-42c98.firebasestorage.app',
  );
}
