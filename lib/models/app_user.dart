import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_role.dart';

/// Representa um documento da colecao `usuarios` no Firestore.
class AppUser {
  const AppUser({
    required this.uid,
    required this.nome,
    required this.email,
    required this.role,
    this.criadoEm,
  });

  final String uid;
  final String nome;
  final String email;
  final UserRole role;
  final DateTime? criadoEm;

  factory AppUser.fromFirestore(String uid, Map<String, dynamic> data) {
    final criadoEmTimestamp = data['criadoEm'];
    return AppUser(
      uid: uid,
      nome: (data['nome'] as String?)?.trim().isNotEmpty == true
          ? data['nome'] as String
          : 'Usuario',
      email: data['email'] as String? ?? '',
      role: UserRole.fromFirestoreValue(data['role'] as String?),
      criadoEm: criadoEmTimestamp is Timestamp
          ? criadoEmTimestamp.toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'email': email,
      'role': role.firestoreValue,
      'criadoEm': criadoEm != null
          ? Timestamp.fromDate(criadoEm!)
          : FieldValue.serverTimestamp(),
    };
  }
}
