// ATENCAO: este arquivo contem valores de PLACEHOLDER.
//
// Normalmente ele e gerado automaticamente pela FlutterFire CLI com:
//   dart pub global activate flutterfire_cli
//   flutterfire configure --project=gymextreme-42c98 --platforms=android,web
//
// Isso exige login com a conta Google/Firebase do cliente, algo que so
// pode ser feito na sua maquina. Antes do build final, rode o comando
// acima na raiz do projeto para sobrescrever este arquivo com as chaves
// reais do projeto gymextreme-42c98 (Android + Web). Veja o README.md
// para o passo a passo completo.
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

  // TODO(flutterfire-configure): substituir pelos valores reais do app Web
  // cadastrado no projeto gymextreme-42c98 (Firebase Console > Configuracoes
  // do projeto > Seus apps > Web).
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_WITH_REAL_WEB_API_KEY',
    appId: 'REPLACE_WITH_REAL_WEB_APP_ID',
    messagingSenderId: 'REPLACE_WITH_REAL_SENDER_ID',
    projectId: 'gymextreme-42c98',
    authDomain: 'gymextreme-42c98.firebaseapp.com',
    storageBucket: 'gymextreme-42c98.firebasestorage.app',
  );

  // TODO(flutterfire-configure): substituir pelos valores reais do app
  // Android cadastrado no projeto gymextreme-42c98 (mesmos valores do
  // android/app/google-services.json real, baixado do Firebase Console).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_WITH_REAL_ANDROID_API_KEY',
    appId: 'REPLACE_WITH_REAL_ANDROID_APP_ID',
    messagingSenderId: 'REPLACE_WITH_REAL_SENDER_ID',
    projectId: 'gymextreme-42c98',
    storageBucket: 'gymextreme-42c98.firebasestorage.app',
  );
}
