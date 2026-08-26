import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../dev/emulator_config.dart';
import '../firebase_options.dart';
import '../models/aluno.dart';
import '../models/anamnese.dart';
import '../models/app_user.dart';
import '../models/avaliacao_fisica.dart';
import '../models/conta_receber.dart';
import '../models/endereco.dart';
import '../models/matricula.dart';
import '../models/pagamento.dart';
import '../models/termo_aceite.dart';
import '../models/treino.dart';
import '../models/user_role.dart';

/// Cadastro e ficha completa do aluno: dados de cadastro (colecao
/// `alunos`), anamnese e termo de responsabilidade (campos dentro do
/// mesmo documento), historico de avaliacoes fisicas, fichas de treino,
/// matriculas e contas a receber (subcolecoes `alunos/{uid}/avaliacoes`,
/// `alunos/{uid}/treinos`, `alunos/{uid}/matriculas` e
/// `alunos/{uid}/contasReceber`).
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

  CollectionReference<Map<String, dynamic>> _pagamentos(String uid) =>
      _alunos.doc(uid).collection('pagamentos');

  CollectionReference<Map<String, dynamic>> _matriculas(String uid) =>
      _alunos.doc(uid).collection('matriculas');

  CollectionReference<Map<String, dynamic>> _contasReceber(String uid) =>
      _alunos.doc(uid).collection('contasReceber');

  /// Lista de alunos (perfil basico), ordenada por nome.
  ///
  /// Ordena em Dart (não com `.orderBy('nome')` no Firestore) de propósito:
  /// um `where` de igualdade combinado com `orderBy` em outro campo exige
  /// um índice composto no Firestore, e sem esse índice a consulta falha
  /// silenciosamente com `failed-precondition` — foi exatamente isso que
  /// quebrou a lista de alunos em produção (cadastro salvava certinho, mas
  /// a lista nunca carregava). A lista de alunos de uma academia é pequena
  /// o bastante pra ordenar no cliente sem custo real, e assim a tela
  /// nunca mais depende de um índice existir no projeto Firebase.
  Stream<List<AppUser>> watchAlunos() {
    return _usuarios
        .where('role', isEqualTo: UserRole.aluno.firestoreValue)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => AppUser.fromFirestore(doc.id, doc.data()))
                  .toList()
                ..sort(
                  (a, b) =>
                      a.nome.toLowerCase().compareTo(b.nome.toLowerCase()),
                ),
        );
  }

  /// Todas as fichas de aluno (coleção `alunos`, um documento por uid) —
  /// usado pelos relatórios/dashboard pra cruzar `proximoVencimento`/
  /// `ativo` de todo mundo de uma vez, sem precisar de uma leitura por
  /// aluno. Sem `.where()`/`.orderBy()` no Firestore, mesmo motivo de
  /// [watchAlunos]: evita depender de índice composto.
  Stream<List<Aluno>> watchTodosAlunos() {
    return _alunos.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Aluno.fromFirestore(doc.id, doc.data())).toList(),
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
    return _avaliacoes(uid)
        .orderBy('data', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AvaliacaoFisica.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> salvarDadosAluno(Aluno aluno) {
    return _alunos
        .doc(aluno.uid)
        .set(aluno.toFirestore(), SetOptions(merge: true));
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

  /// Historico de pagamentos registrados pela recepcao, mais recente
  /// primeiro.
  Stream<List<Pagamento>> watchPagamentos(String uid) {
    return _pagamentos(uid)
        .orderBy('registradoEm', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Pagamento.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Registra que a recepcao recebeu o pagamento (dinheiro, PIX, cartao ou
  /// transferencia — fora do app nesta primeira versao, sem gateway) e
  /// avanca `proximoVencimento` em 1 mes a partir do vencimento atual
  /// (ou de hoje, se ainda nao havia nenhum configurado).
  Future<void> marcarPagamentoRecebido(
    String uid, {
    required DateTime? vencimentoAtual,
    required String staffUid,
    required String staffNome,
  }) async {
    final base = vencimentoAtual ?? DateTime.now();
    final novoVencimento = _adicionarUmMes(base);

    await _alunos.doc(uid).set({
      'proximoVencimento': Timestamp.fromDate(novoVencimento),
    }, SetOptions(merge: true));

    await _pagamentos(uid).add(
      Pagamento(
        registradoEm: DateTime.now(),
        vencimentoAnterior: vencimentoAtual,
        novoVencimento: novoVencimento,
        registradoPorUid: staffUid,
        registradoPorNome: staffNome,
      ).toFirestore(),
    );
  }

  /// Define o primeiro vencimento de um aluno que ainda nao tem nenhum
  /// configurado, sem que isso conte como um pagamento recebido.
  Future<void> definirVencimentoInicial(String uid, DateTime vencimento) {
    return _alunos.doc(uid).set({
      'proximoVencimento': Timestamp.fromDate(vencimento),
    }, SetOptions(merge: true));
  }

  /// Mesmo dia do mes, um mes a frente — com fallback pro ultimo dia do
  /// mes de destino quando ele for mais curto (ex.: 31/01 -> 28 ou 29/02).
  DateTime _adicionarUmMes(DateTime data) {
    final novoMes = data.month == 12 ? 1 : data.month + 1;
    final novoAno = data.month == 12 ? data.year + 1 : data.year;
    final ultimoDiaDoNovoMes = DateTime(novoAno, novoMes + 1, 0).day;
    final dia = data.day > ultimoDiaDoNovoMes ? ultimoDiaDoNovoMes : data.day;
    return DateTime(novoAno, novoMes, dia);
  }

  /// Histórico de matrículas de UM aluno, mais recente primeiro. Usada
  /// pela tela administrativa quando filtrada por um aluno específico.
  Stream<List<Matricula>> watchMatriculas(String uid) {
    return _matriculas(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Matricula.fromFirestore(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.dataInicio.compareTo(a.dataInicio)),
    );
  }

  /// Todas as matrículas de TODOS os alunos (collection group query sobre
  /// `matriculas`) — alimenta a tela administrativa "Matrículas", que
  /// precisa listar/filtrar por status/aluno/plano de uma vez, sem abrir
  /// aluno por aluno.
  ///
  /// Sem `.orderBy()`/`.where()` no Firestore de propósito — mesmo motivo
  /// de `watchAlunos()`: um `where`/`orderBy` sobre uma collection group
  /// query também pode exigir índice composto, e a lista de matrículas de
  /// uma academia é pequena o bastante pra filtrar/ordenar no cliente sem
  /// custo real. A tela usa `Matricula.alunoId`/`planoId` (gravados no
  /// próprio documento) pra filtrar sem precisar do path do aluno.
  Stream<List<Matricula>> watchTodasMatriculas() {
    return _firestore.collectionGroup('matriculas').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Matricula.fromFirestore(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.dataInicio.compareTo(a.dataInicio)),
    );
  }

  /// Cria uma matrícula nova pro aluno. Se ele já tiver uma matrícula com
  /// `status == ativa`, ela é automaticamente encerrada (`cancelada`) na
  /// mesma transação — garante o invariante "no máximo uma matrícula ativa
  /// por aluno" mesmo sob concorrência (ex.: dois dispositivos da recepção
  /// ao mesmo tempo), sem apagar o histórico.
  ///
  /// Também serve pra "renovar": chame de novo com o novo período/plano —
  /// se a matrícula anterior já não estiver mais `ativa` (ex.: já expirou
  /// e virou `vencida`), ela fica intacta no histórico, sem ser tocada.
  Future<String> criarMatricula(
    String alunoUid, {
    required String planoId,
    required DateTime dataInicio,
    required DateTime dataVencimento,
    required double valorContratado,
    String? formaPagamento,
    String? observacao,
  }) async {
    final ativasSnap = await _matriculas(
      alunoUid,
    ).where('status', isEqualTo: StatusMatricula.ativa.name).get();

    return _firestore.runTransaction<String>((transaction) async {
      // Todas as leituras da transação precisam vir antes de qualquer
      // escrita (regra do Firestore) — por isso o get() de cada matrícula
      // ainda ativa roda num laço separado do laço que as encerra.
      final frescas = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final doc in ativasSnap.docs) {
        frescas.add(await transaction.get(doc.reference));
      }

      for (final fresca in frescas) {
        if (fresca.exists && fresca.data()?['status'] == StatusMatricula.ativa.name) {
          transaction.update(fresca.reference, {
            'status': StatusMatricula.cancelada.name,
            'atualizadoEm': FieldValue.serverTimestamp(),
          });
        }
      }

      final novaRef = _matriculas(alunoUid).doc();
      transaction.set(
        novaRef,
        Matricula(
          alunoId: alunoUid,
          planoId: planoId,
          dataInicio: dataInicio,
          dataVencimento: dataVencimento,
          valorContratado: valorContratado,
          formaPagamento: formaPagamento,
          observacao: observacao,
        ).toFirestore(),
      );
      return novaRef.id;
    });
  }

  /// Cancela uma matrícula (fica no histórico, nunca é apagada).
  Future<void> cancelarMatricula(String alunoUid, String matriculaId) {
    return _matriculas(alunoUid).doc(matriculaId).set({
      'status': StatusMatricula.cancelada.name,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Contas a receber de UM aluno, vencimento mais próximo primeiro.
  Stream<List<ContaReceber>> watchContasReceber(String uid) {
    return _contasReceber(uid).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ContaReceber.fromFirestore(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.vencimento.compareTo(b.vencimento)),
    );
  }

  /// Todas as contas a receber de TODOS os alunos (collection group query
  /// sobre `contasReceber`) — alimenta a tela administrativa "Contas a
  /// Receber". Mesmo motivo de `watchTodasMatriculas()` pra não usar
  /// `.orderBy()`/`.where()` no Firestore: evita depender de índice
  /// composto; a tela filtra/ordena no cliente.
  Stream<List<ContaReceber>> watchTodasContasReceber() {
    return _firestore.collectionGroup('contasReceber').snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ContaReceber.fromFirestore(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.vencimento.compareTo(b.vencimento)),
    );
  }

  /// Lança uma cobrança nova pro aluno — sempre nasce `pendente`, nunca é
  /// criada já como paga (isso passa por [registrarRecebimento]).
  Future<String> criarContaReceber(
    String alunoUid, {
    String? matriculaId,
    required String descricao,
    required double valorOriginal,
    double desconto = 0,
    double jurosMulta = 0,
    required DateTime vencimento,
    String? formaPagamento,
    String? observacao,
    required String staffUid,
    required String staffNome,
  }) async {
    final ref = await _contasReceber(alunoUid).add(
      ContaReceber(
        alunoId: alunoUid,
        matriculaId: matriculaId,
        descricao: descricao,
        valorOriginal: valorOriginal,
        desconto: desconto,
        jurosMulta: jurosMulta,
        vencimento: vencimento,
        formaPagamento: formaPagamento,
        observacao: observacao,
        criadoPorUid: staffUid,
        criadoPorNome: staffNome,
      ).toFirestore(),
    );
    return ref.id;
  }

  /// Gera uma cobrança a partir de uma matrícula já existente — copia só
  /// valor/vencimento/forma de pagamento no momento da criação (nunca lê
  /// a matrícula de novo depois), o mesmo raciocínio de "cópia na
  /// criação" que `Matricula.valorContratado` já usa em relação ao
  /// `Plano`. Não duplica nem altera nada na matrícula em si.
  Future<String> criarContaReceberDeMatricula(
    String alunoUid,
    Matricula matricula, {
    String? descricao,
    required String staffUid,
    required String staffNome,
  }) {
    return criarContaReceber(
      alunoUid,
      matriculaId: matricula.id,
      descricao: descricao ?? 'Matrícula',
      valorOriginal: matricula.valorContratado,
      vencimento: matricula.dataVencimento,
      formaPagamento: matricula.formaPagamento,
      staffUid: staffUid,
      staffNome: staffNome,
    );
  }

  /// Edita os dados básicos de uma cobrança (descrição, valor, desconto,
  /// juros/multa, vencimento, vínculo com matrícula, observação). Nunca
  /// mexe em status/valorPago/dataPagamento/responsável pelo recebimento —
  /// isso é sempre [registrarRecebimento], nunca esta função.
  Future<void> atualizarContaReceber(
    String alunoUid,
    String contaId, {
    String? matriculaId,
    required String descricao,
    required double valorOriginal,
    required double desconto,
    required double jurosMulta,
    required DateTime vencimento,
    String? observacao,
  }) {
    return _contasReceber(alunoUid).doc(contaId).set({
      'matriculaId': matriculaId,
      'descricao': descricao,
      'valorOriginal': valorOriginal,
      'desconto': desconto,
      'jurosMulta': jurosMulta,
      'vencimento': Timestamp.fromDate(vencimento),
      'observacao': observacao,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Registra o recebimento de uma cobrança — marca `status: pago` sem
  /// apagar nada: mesmo documento, histórico completo preservado (quem
  /// lançou continua em `criadoPor*`, quem recebeu fica em
  /// `recebidoPor*`). Desconto/juros podem ser ajustados aqui mesmo (ex.:
  /// desconto concedido só na hora de pagar).
  Future<void> registrarRecebimento(
    String alunoUid,
    String contaId, {
    required double valorPago,
    required double desconto,
    required double jurosMulta,
    required DateTime dataPagamento,
    String? formaPagamento,
    String? observacao,
    required String staffUid,
    required String staffNome,
  }) {
    return _contasReceber(alunoUid).doc(contaId).set({
      'status': StatusContaReceber.pago.name,
      'valorPago': valorPago,
      'desconto': desconto,
      'jurosMulta': jurosMulta,
      'dataPagamento': Timestamp.fromDate(dataPagamento),
      'formaPagamento': formaPagamento,
      'observacao': observacao,
      'recebidoPorUid': staffUid,
      'recebidoPorNome': staffNome,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// "Exclui" uma cobrança sem apagar o documento — marca `cancelado`,
  /// mesmo padrão de `PlanoService.excluirPlano`/`cancelarMatricula`
  /// (preserva o histórico financeiro, nunca reaproveita o registro).
  Future<void> excluirContaReceber(String alunoUid, String contaId) {
    return _contasReceber(alunoUid).doc(contaId).set({
      'status': StatusContaReceber.cancelado.name,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Fichas de treino do aluno, mais recentes/ativas primeiro.
  Stream<List<Treino>> watchTreinos(String uid) {
    return _treinos(uid)
        .orderBy('ordem')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Treino.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Uma ficha de treino específica — usado pela tela de execução, que
  /// só precisa de um treino por vez (não da lista inteira via
  /// [watchTreinos]). `null` se o documento não existir.
  Future<Treino?> buscarTreino(String alunoUid, String treinoId) async {
    final doc = await _treinos(alunoUid).doc(treinoId).get();
    final data = doc.data();
    if (data == null) return null;
    return Treino.fromFirestore(doc.id, data);
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
    return salvarTreino(
      alunoUid,
      copia,
      staffUid: staffUid,
      staffNome: staffNome,
    );
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
    return salvarTreino(
      destinoUid,
      copia,
      staffUid: staffUid,
      staffNome: staffNome,
    );
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
      if (usarEmulador) {
        await secondaryAuth.useAuthEmulator('localhost', 9099);
      }
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
