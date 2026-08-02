import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../models/cargo.dart';
import '../models/permission.dart';
import '../models/user_role.dart';

/// Cadastro e gestao de contas de staff (ADM/Recepcionista/Personal/cargos
/// customizados) na colecao `usuarios`.
class FuncionarioService {
  FuncionarioService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _firestore.collection('usuarios');

  /// Lista de funcionarios (ADM, Personal legado e Funcionario), ordenada
  /// por nome. Nao inclui alunos.
  Stream<List<AppUser>> watchFuncionarios() {
    return _usuarios
        .where(
          'role',
          whereIn: [
            UserRole.adm.firestoreValue,
            UserRole.personal.firestoreValue,
            UserRole.funcionario.firestoreValue,
          ],
        )
        .orderBy('nome')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUser.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Cria a conta de login (Firebase Auth) e o documento `usuarios/{uid}`
  /// de um novo funcionario. Usa o mesmo truque de app Firebase secundario
  /// e temporario de `AlunoService.cadastrarAluno`, para que a criacao da
  /// conta nao derrube a sessao do ADM que esta cadastrando.
  Future<void> cadastrarFuncionario({
    required String nome,
    required String email,
    required String senhaInicial,
    required Cargo cargo,
    required Set<Permission> permissoes,
  }) async {
    final secondaryApp = await Firebase.initializeApp(
      name: 'gymextreme-cadastro-${DateTime.now().microsecondsSinceEpoch}',
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      late final String uid;
      try {
        final credential = await secondaryAuth.createUserWithEmailAndPassword(
          email: email.trim(),
          password: senhaInicial,
        );
        uid = credential.user!.uid;
      } on FirebaseAuthException catch (e) {
        throw FuncionarioServiceException(_messageFor(e.code));
      } finally {
        await secondaryAuth.signOut();
      }

      final role = cargo.id == CargosPadrao.administrador.id
          ? UserRole.adm
          : UserRole.funcionario;

      await _usuarios.doc(uid).set(
        AppUser(
          uid: uid,
          nome: nome.trim(),
          email: email.trim(),
          role: role,
          cargoId: cargo.id,
          permissoes: permissoes,
        ).toFirestore(),
      );
    } finally {
      await secondaryApp.delete();
    }
  }

  Future<void> atualizarPermissoes(String uid, Set<Permission> permissoes) {
    return _usuarios.doc(uid).set({
      'permissoes': permissoes.map((p) => p.firestoreValue).toList(),
    }, SetOptions(merge: true));
  }

  String _messageFor(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ja existe uma conta com esse e-mail.';
      case 'invalid-email':
        return 'E-mail invalido.';
      case 'weak-password':
        return 'Senha muito fraca (minimo 6 caracteres).';
      case 'network-request-failed':
        return 'Sem conexao com a internet. Verifique sua rede.';
      default:
        return 'Nao foi possivel criar o cadastro ($code).';
    }
  }
}

/// Erro de cadastro com mensagem pronta para exibir ao usuario.
class FuncionarioServiceException implements Exception {
  FuncionarioServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
