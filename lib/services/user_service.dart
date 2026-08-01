import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Leitura dos dados de perfil na colecao `usuarios` do Firestore.
class UserService {
  UserService({FirebaseFirestore? firestore})
    : _usuarios = (firestore ?? FirebaseFirestore.instance).collection(
        'usuarios',
      );

  final CollectionReference<Map<String, dynamic>> _usuarios;

  /// Acompanha em tempo real o documento de perfil do usuario logado.
  Stream<AppUser?> watchUser(String uid) {
    return _usuarios.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return AppUser.fromFirestore(uid, data);
    });
  }
}
