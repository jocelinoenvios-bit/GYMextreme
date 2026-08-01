import 'package:firebase_auth/firebase_auth.dart';

/// Camada fina sobre o FirebaseAuth, traduzindo erros para mensagens em
/// portugues que as telas podem exibir direto ao usuario.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<void> signIn({required String email, required String password}) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_messageFor(e.code));
    }
  }

  Future<void> signOut() => _firebaseAuth.signOut();

  String _messageFor(String code) {
    switch (code) {
      case 'invalid-email':
        return 'E-mail invalido.';
      case 'user-disabled':
        return 'Este usuario foi desativado. Fale com a administracao.';
      case 'user-not-found':
      case 'invalid-credential':
        return 'E-mail ou senha incorretos.';
      case 'wrong-password':
        return 'E-mail ou senha incorretos.';
      case 'too-many-requests':
        return 'Muitas tentativas. Aguarde alguns minutos e tente de novo.';
      case 'network-request-failed':
        return 'Sem conexao com a internet. Verifique sua rede.';
      default:
        return 'Nao foi possivel completar a operacao ($code).';
    }
  }
}

/// Erro de autenticacao com mensagem pronta para exibir ao usuario.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
