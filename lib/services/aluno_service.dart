import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';
import '../models/aluno.dart';
import '../models/anamnese.dart';
import '../models/app_user.dart';
import '../models/avaliacao_fisica.dart';
import '../models/endereco.dart';
import '../models/termo_aceite.dart';
import '../models/treino.dart';
import '../models/user_role.dart';

/// Cadastro e ficha completa do aluno: dados de cadastro (colecao
/// `alunos`), anamnese e termo de responsabilidade (campos dentro do
/// mesmo documento), historico de avaliacoes fisicas e fichas de treino
/// (subcolecoes `alunos/{uid}/avaliacoes` e `alunos/{uid}/treinos`).
class AlunoService {
  AlunoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usuarios =>
      _firestore.collection('usuarios');

  CollectionReference<Map<String, dynamic>> get _alunos =>
      _firestore.collection('alunos');

  CollectionReference<Map<String, dynamic>> _avaliacoes(String uid) =>
      _alunos.doc(uid).collection('avaliacoes');

  CollectionReference<Map<String, dynamic>> _treinos(String uid) =>
      _alunos.doc(uid).collection('treinos');

  /// Lista de alunos (perfil basico), ordenada por nome.
  Stream<List<AppUser>> watchAlunos() {
    return _usuarios
        .where('role', isEqualTo: UserRole.aluno.firestoreValue)
        .orderBy('nome')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AppUser.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<Aluno?> watchAluno(String uid) {
    return _alunos.doc(uid).snapshots().map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return Aluno.fromFirestore(uid, data);
    });
  }

  Stream<Anamnese?> watchAnamnese(String uid) {
    return _alunos.doc(uid).snapshots().map((snapshot) {
      final anamnese = snapshot.data()?['anamnese'];
      if (anamnese == null) return null;
      return Anamnese.fromFirestore(Map<String, dynamic>.from(anamnese));
    });
  }

  Stream<TermoAceite> watchTermoAceite(String uid) {
    return _alunos.doc(uid).snapshots().map((snapshot) {
      final termo = snapshot.data()?['termo'];
      if (termo == null) return TermoAceite.naoAceito;
      return TermoAceite.fromFirestore(Map<String, dynamic>.from(termo));
    });
  }

  Stream<List<AvaliacaoFisica>> watchAvaliacoes(String uid) {
    return _avaliacoes(
      uid,
    ).orderBy('data', descending: true).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => AvaliacaoFisica.fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<void> salvarDadosAluno(Aluno aluno) {
    return _alunos.doc(aluno.uid).set(aluno.toFirestore(), SetOptions(merge: true));
  }

  Future<void> salvarAnamnese(String uid, Anamnese anamnese) {
    return _alunos.doc(uid).set({
      'anamnese': anamnese.toFirestore(),
    }, SetOptions(merge: true));
  }

  Future<void> salvarTermoAceite(String uid, TermoAceite termo) {
    return _alunos.doc(uid).set({
      'termo': termo.toFirestore(),
    }, SetOptions(merge: true));
  }

  Future<void> adicionarAvaliacao(String uid, AvaliacaoFisica avaliacao) {
    return _avaliacoes(uid).add(avaliacao.toFirestore());
  }

  /// Fichas de treino do aluno, mais recentes/ativas primeiro.
  Stream<List<Treino>> watchTreinos(String uid) {
    return _treinos(uid).orderBy('ordem').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Treino.fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }

  /// Cria (se `treino.id` for nulo) ou atualiza uma ficha de treino.
  /// `staffUid`/`staffNome` identificam quem fez a acao — carimbados em
  /// `criadoPor*` só na criação e em `atualizadoPor*` sempre.
  Future<String> salvarTreino(
    String alunoUid,
    Treino treino, {
    required String staffUid,
    required String staffNome,
  }) async {
    final dados = treino.toFirestore();
    dados['atualizadoPorUid'] = staffUid;
    dados['atualizadoPorNome'] = staffNome;
    if (treino.id == null) {
      dados['criadoPorUid'] = staffUid;
      dados['criadoPorNome'] = staffNome;
      final ref = await _treinos(alunoUid).add(dados);
      return ref.id;
    }
    await _treinos(alunoUid).doc(treino.id).set(dados, SetOptions(merge: true));
    return treino.id!;
  }

  Future<void> excluirTreino(String alunoUid, String treinoId) {
    return _treinos(alunoUid).doc(treinoId).delete();
  }

  /// Duplica um treino do mesmo aluno (vira um novo documento, mesma
  /// letra/grupo/exercicios, nome com "(cópia)").
  Future<String> duplicarTreino(
    String alunoUid,
    Treino treino, {
    required String staffUid,
    required String staffNome,
  }) {
    final copia = Treino(
      nome: '${treino.nome} (cópia)',
      letra: treino.letra,
      grupoMuscular: treino.grupoMuscular,
      ordem: treino.ordem,
      exercicios: treino.exercicios,
    );
    return salvarTreino(alunoUid, copia, staffUid: staffUid, staffNome: staffNome);
  }

  /// Copia um treino de outro aluno pra este (usado quando o personal
  /// reaproveita uma ficha já pronta).
  Future<String> copiarTreinoDeOutroAluno({
    required String origemUid,
    required String treinoId,
    required String destinoUid,
    required String staffUid,
    required String staffNome,
  }) async {
    final doc = await _treinos(origemUid).doc(treinoId).get();
    final data = doc.data();
    if (data == null) {
      throw AlunoServiceException('Treino de origem não encontrado.');
    }
    final original = Treino.fromFirestore(doc.id, data);
    final copia = Treino(
      nome: original.nome,
      letra: original.letra,
      grupoMuscular: original.grupoMuscular,
      ordem: original.ordem,
      exercicios: original.exercicios,
    );
    return salvarTreino(destinoUid, copia, staffUid: staffUid, staffNome: staffNome);
  }

  /// Cria a conta de login (Firebase Auth) e os documentos de cadastro
  /// de um novo aluno. Usa um app Firebase secundario e temporario para
  /// que a criacao da conta do aluno nao derrube a sessao do ADM/Personal
  /// que esta cadastrando (o SDK do Firebase Auth loga automaticamente
  /// no usuario recem-criado no app em que a chamada e feita).
  Future<String> cadastrarAluno({
    required String nome,
    required String email,
    required String senhaInicial,
    Sexo? sexo,
    DateTime? dataNascimento,
    int? idade,
    String? cpf,
    String? rg,
    String? telefone,
    String? whatsapp,
    Endereco endereco = Endereco.vazio,
    String? contatoEmergenciaNome,
    String? contatoEmergenciaTelefone,
    String? observacoes,
    DateTime? dataInicio,
    int? diaVencimento,
    required String cadastradoPorUid,
    required String cadastradoPorNome,
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
        throw AlunoServiceException(_messageFor(e.code));
      } finally {
        await secondaryAuth.signOut();
      }

      final batch = _firestore.batch();
      batch.set(
        _usuarios.doc(uid),
        AppUser(
          uid: uid,
          nome: nome.trim(),
          email: email.trim(),
          role: UserRole.aluno,
        ).toFirestore(),
      );
      batch.set(
        _alunos.doc(uid),
        Aluno(
          uid: uid,
          sexo: sexo,
          dataNascimento: dataNascimento,
          idadeInformada: idade,
          cpf: cpf,
          rg: rg,
          telefone: telefone,
          whatsapp: whatsapp,
          endereco: endereco,
          contatoEmergenciaNome: contatoEmergenciaNome,
          contatoEmergenciaTelefone: contatoEmergenciaTelefone,
          observacoes: observacoes,
          dataInicio: dataInicio,
          diaVencimento: diaVencimento,
          cadastradoPorUid: cadastradoPorUid,
          cadastradoPorNome: cadastradoPorNome,
        ).toFirestore(),
      );
      await batch.commit();
      return uid;
    } finally {
      await secondaryApp.delete();
    }
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
class AlunoServiceException implements Exception {
  AlunoServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
