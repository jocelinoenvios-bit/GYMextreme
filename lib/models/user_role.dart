/// Os niveis de acesso do GymExtreme.
///
/// O valor gravado no Firestore (campo `role` da colecao `usuarios`) e
/// sempre o de [UserRole.firestoreValue]: "adm", "personal", "funcionario"
/// ou "aluno".
///
/// `funcionario` e o "balde" generico pra qualquer conta de staff criada a
/// partir do sistema de cargos/permissoes (Recepcionista, novos Personal
/// Trainers, ou qualquer cargo customizado que a academia crie no futuro) —
/// o acesso real dessas contas vem de `AppUser.permissoes`
/// (ver [PermissionService]), nao deste enum. `adm` continua com acesso
/// total sempre. `personal` e mantido só pelas contas antigas ja gravadas
/// no Firestore antes deste sistema existir (ver fallback em
/// `PermissionService.effectivePermissions`).
enum UserRole {
  adm,
  personal,
  funcionario,
  aluno;

  static UserRole fromFirestoreValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.firestoreValue == value,
      orElse: () => UserRole.aluno,
    );
  }

  String get firestoreValue => name;

  String get welcomeLabel => switch (this) {
    UserRole.adm => 'ADM',
    UserRole.personal => 'Personal',
    UserRole.funcionario => 'Equipe',
    UserRole.aluno => 'Aluno',
  };

  /// ADM, Personal (legado) e Funcionario sao a equipe da academia. O
  /// proprio aluno nao tem essas areas (chega em modulo futuro de
  /// autoatendimento). Isso so decide se a conta e "de staff" ou nao — QUAIS
  /// telas/acoes especificas cada um ve depende de [PermissionService].
  bool get isStaff =>
      this == UserRole.adm ||
      this == UserRole.personal ||
      this == UserRole.funcionario;
}
