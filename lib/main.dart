import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app/gymextreme_app.dart';
import 'dev/emulator_config.dart';
import 'firebase_options.dart';

/// Recebe pushes de mensalidade quando o app está em segundo plano/fechado.
/// Precisa ser uma função de nível superior (fora de qualquer classe) — o
/// plugin roda isso num isolate separado. Não faz nada além de deixar o
/// isolate inicializar o Firebase corretamente: o texto do push já aparece
/// sozinho (payload `notification`), sem processamento extra nesta
/// primeira versão.
@pragma('vm:entry-point')
Future<void> tratarMensagemEmSegundoPlano(RemoteMessage mensagem) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (!kIsWeb) {
    // No Web isso exige um service worker `firebase-messaging-sw.js`
    // dedicado (ainda nao configurado aqui) — sem ele o registro so
    // falharia silenciosamente ou, dependendo da versao do plugin, gerava
    // erro no arranque do app. A versao Web (uso no computador da
    // administracao) nao depende de push, so o Android precisa.
    FirebaseMessaging.onBackgroundMessage(tratarMensagemEmSegundoPlano);
  }
  if (usarEmulador) {
    await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    await FirebaseStorage.instance.useStorageEmulator('localhost', 9199);
  }
  runApp(const GymExtremeApp());
}
