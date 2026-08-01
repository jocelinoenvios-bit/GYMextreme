/// Os 3 niveis de acesso do GymExtreme.
///
/// O valor gravado no Firestore (campo `role` da colecao `usuarios`) e
/// sempre o de [UserRole.firestoreValue]: "adm", "personal" ou "aluno".
enum UserRole {
  adm,
  personal,
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
    UserRole.aluno => 'Aluno',
  };
}
