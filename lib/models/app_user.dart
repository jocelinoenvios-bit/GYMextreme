import 'package:cloud_firestore/cloud_firestore.dart';

import 'permission.dart';
import 'user_role.dart';

/// Representa um documento da colecao `usuarios` no Firestore.
class AppUser {
  const AppUser({
    required this.uid,
    required this.nome,
    required this.email,
    required this.role,
    this.criadoEm,
    this.cargoId,
    this.permissoes = const {},
  });

  final String uid;
  final String nome;
  final String email;
  final UserRole role;
  final DateTime? criadoEm;

  /// Id do cargo (embutido ou customizado, ver `Cargo`) usado como modelo
  /// ao criar esta conta. Só se aplica a `role == funcionario`; nulo para
  /// adm/personal/aluno.
  final String? cargoId;

  /// Permissoes individuais desta conta (ja resolvidas a partir do cargo
  /// escolhido no cadastro e ajustaveis depois uma a uma). Vazio para
  /// contas antigas (adm/personal legado) e para alunos — ver
  /// `PermissionService.effectivePermissions` para a regra de fallback.
  final Set<Permission> permissoes;

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
      cargoId: data['cargoId'] as String?,
      permissoes: Permission.setFromFirestoreValues(
        data['permissoes'] as List<dynamic>?,
      ),
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
      if (cargoId != null) 'cargoId': cargoId,
      'permissoes': permissoes
          .map((permission) => permission.firestoreValue)
          .toList(),
    };
  }
}
