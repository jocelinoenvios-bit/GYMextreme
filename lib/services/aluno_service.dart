import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../dev/emulator_config.dart';
import '../firebase_options.dart';
import '../models/aluno.dart';
import '../models/anamnese.dart';
import '../models/app_user.dart';
import '../models/avaliacao_fisica.dart';
import '../models/caixa_movimentacao.dart';
import '../models/conta_receber.dart';
import '../models/endereco.dart';
import '../models/historico_treino.dart';
import '../models/matricula.dart';
import '../models/mensagem.dart';
import '../models/pagamento.dart';
import '../models/termo_aceite.dart';
import '../models/treino.dart';
import '../models/user_role.dart';
import 'renovacao_matricula.dart';
import '../utils/lembrete_vencimento.dart';
import '../utils/mensalidade_utils.dart';

/// Cadastro e ficha completa do aluno: dados de cadastro (colecao
/// `alunos`), anamnese e termo de responsabilidade (campos dentro do
/// mesmo documento), historico de avaliacoes fisicas, fichas de treino,
/// matriculas, contas a receber e mensagens (subcolecoes
/// `alunos/{uid}/avaliacoes`, `alunos/{uid}/treinos`,
/// `alunos/{uid}/matriculas`, `alunos/{uid}/contasReceber` e
/// `alunos/{uid}/mensagens`).
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

  /// Registros de presença/frequência (treino realizado/falta) —
  /// SEMPRE separada de `treinos` (a ficha prescrita): a ficha nunca
  /// depende de existir registro aqui. Ver `HistoricoTreino` e a regra
  /// em `firestore.rules` (só staff com `criarTreinos`/`editarTreinos`
  /// grava; o aluno só lê o próprio).
  CollectionReference<Map<String, dynamic>> _historicoTreinos(String uid) =>
      _alunos.doc(uid).collection('historicoTreinos');

  CollectionReference<Map<String, dynamic>> _pagamentos(String uid) =>
      _alunos.doc(uid).collection('pagamentos');

  CollectionReference<Map<String, dynamic>> _matriculas(String uid) =>
      _alunos.doc(uid).collection('matriculas');

  CollectionReference<Map<String, dynamic>> _contasReceber(String uid) =>
      _alunos.doc(uid).collection('contasReceber');

  /// Mensagens enviadas por um membro da equipe pro aluno (ver
  /// `Permission.chat`) — só envio manual por enquanto, sem avisos
  /// automáticos ainda.
  CollectionReference<Map<String, dynamic>> _mensagens(String uid) =>
      _alunos.doc(uid).collection('mensagens');

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

  /// Salva os dados de CADASTRO do aluno (nome de contato, documento,
  /// endereço, foto etc.) — nunca toca nos campos operacionais/
  /// financeiros: `ativo`, `bloqueado`, `proximoVencimento`,
  /// `unidadeId`, `dataInativacao`, `dataReativacao`,
  /// `reativadoPorUid`/`reativadoPorNome`, `whatsappOptIn`. Esses só
  /// mudam através das operações específicas já autorizadas pra isso
  /// (`marcarPagamentoRecebido`, `registrarRecebimento`,
  /// `reativarAluno`, a automação diária de inadimplência via Admin
  /// SDK) — nunca como efeito colateral de editar um dado cadastral.
  ///
  /// Antes esta função usava `aluno.toFirestore()` (grava TODOS os
  /// campos do objeto) — como a tela que chama isto (`DadosTab`) só
  /// preenche os campos cadastrais ao reconstruir o `Aluno`, os campos
  /// operacionais caíam nos valores padrão do construtor (`ativo:
  /// true`, `bloqueado: false`, os demais `null`) e o `merge: true`
  /// ainda assim os sobrescrevia — apagando silenciosamente o
  /// vencimento da mensalidade e reativando/desbloqueando o aluno a
  /// cada edição de cadastro. Corrigido serializando só os campos
  /// cadastrais via [dadosCadastraisParaFirestore] — não importa o que
  /// o `Aluno` passado tenha nos campos operacionais, essa função nunca
  /// os inclui no mapa gravado.
  Future<void> salvarDadosAluno(Aluno aluno) {
    return _alunos
        .doc(aluno.uid)
        .set(dadosCadastraisParaFirestore(aluno), SetOptions(merge: true));
  }

  /// Monta o mapa gravado por [salvarDadosAluno] — extraído como função
  /// estática (pura, sem Firestore) pra poder testar diretamente que os
  /// campos operacionais/financeiros NUNCA aparecem nas chaves do mapa,
  /// não importa o que o [Aluno] passado contenha neles (ver
  /// test/aluno_service_test.dart).
  static Map<String, dynamic> dadosCadastraisParaFirestore(Aluno aluno) {
    return {
      'sexo': aluno.sexo?.name,
      'dataNascimento': aluno.dataNascimento != null
          ? Timestamp.fromDate(aluno.dataNascimento!)
          : null,
      'idade': aluno.idadeInformada,
      'fotoUrl': aluno.fotoUrl,
      'cpf': aluno.cpf,
      'rg': aluno.rg,
      'telefone': aluno.telefone,
      'whatsapp': aluno.whatsapp,
      'endereco': aluno.endereco.toFirestore(),
      'contatoEmergenciaNome': aluno.contatoEmergenciaNome,
      'contatoEmergenciaTelefone': aluno.contatoEmergenciaTelefone,
      'observacoes': aluno.observacoes,
      'dataInicio': aluno.dataInicio != null
          ? Timestamp.fromDate(aluno.dataInicio!)
          : null,
      'diaVencimento': aluno.diaVencimento,
      if (aluno.cadastradoPorUid != null) 'cadastradoPorUid': aluno.cadastradoPorUid,
      if (aluno.cadastradoPorNome != null) 'cadastradoPorNome': aluno.cadastradoPorNome,
    };
  }

  /// Só a foto de perfil — usado pelo próprio aluno (Configurações →
  /// Trocar foto de perfil). A regra do Firestore deixa o aluno mexer só
  /// neste campo do próprio cadastro, e só apontando pra foto dele.
  Future<void> salvarFotoUrl(String uid, String fotoUrl) {
    return _alunos.doc(uid).set({'fotoUrl': fotoUrl}, SetOptions(merge: true));
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

  /// Mensagens que o aluno vê, mais recente primeiro — sem as que ele
  /// mesmo tirou da lista (que continuam existindo pro staff, ver
  /// [arquivarMensagem]).
  Stream<List<Mensagem>> watchMensagens(String uid) {
    return _mensagens(uid)
        .orderBy('criadoEm', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Mensagem.fromFirestore(doc.id, doc.data()))
              .where((mensagem) => !mensagem.arquivadaPeloAluno)
              .toList(),
        );
  }

  /// Tudo que a equipe já enviou, de todos os alunos, mais recente
  /// primeiro.
  ///
  /// Varre as subcoleções `mensagens` de todos os alunos de uma vez
  /// (collection group) em vez de consultar aluno por aluno. Exige um
  /// índice de escopo "grupo de coleções" no campo `criadoEm` — ver
  /// `firestore.indexes.json`. O [limite] existe porque essa lista só
  /// cresce: ninguém rola três anos de avisos.
  Stream<List<Mensagem>> watchMensagensEnviadas({int limite = 300}) {
    return _firestore
        .collectionGroup('mensagens')
        .orderBy('criadoEm', descending: true)
        .limit(limite)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Mensagem.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Envia um aviso pro aluno [uid] — exige a permissão `chat` (ver
  /// `firestore.rules`), reforçada aqui só pela UI (o botão "Enviar
  /// mensagem" já fica escondido sem a permissão).
  Future<void> enviarMensagem(
    String uid, {
    required String texto,
    required String remetenteUid,
    required String remetenteNome,
    required String alunoNome,
  }) {
    return _mensagens(uid).add(
      Mensagem(
        texto: texto,
        remetenteUid: remetenteUid,
        remetenteNome: remetenteNome,
        alunoUid: uid,
        alunoNome: alunoNome,
      ).toFirestore(),
    );
  }

  /// Garante que o lembrete de vencimento ([idLembreteVencimento]) esteja
  /// na caixa do aluno — chamado pelo app do próprio aluno ao abrir, dentro
  /// da janela de 3 dias antes do vencimento ([deveLembrarVencimento]).
  ///
  /// Um documento por vencimento, com id fixo: se já existe (o aluno abriu
  /// o app ontem, ou tirou o aviso da lista), não faz nada. Devolve se
  /// criou agora.
  Future<bool> garantirLembreteVencimento(
    String uid, {
    required DateTime vencimento,
    required String alunoNome,
  }) async {
    final ref = _mensagens(uid).doc(idLembreteVencimento(vencimento));
    final existente = await ref.get();
    if (existente.exists) return false;
    await ref.set(
      Mensagem(
        texto: textoLembreteVencimento(vencimento),
        remetenteUid: remetenteLembreteAutomatico,
        remetenteNome: 'GYM XTREME',
        alunoUid: uid,
        alunoNome: alunoNome,
        automatica: true,
      ).toFirestore(),
    );
    return true;
  }

  /// Marca como lidas as mensagens que o aluno acabou de ver. Recebe a
  /// lista pronta (em vez de consultar de novo) porque quem chama já tem
  /// o snapshot aberto na tela.
  Future<void> marcarMensagensComoLidas(String uid, Iterable<String> ids) {
    if (ids.isEmpty) return Future.value();
    final lote = _firestore.batch();
    for (final id in ids) {
      lote.update(_mensagens(uid).doc(id), {
        'lidaEm': FieldValue.serverTimestamp(),
      });
    }
    return lote.commit();
  }

  /// O aluno tira o aviso da lista dele. Não apaga: o staff continua
  /// vendo nas enviadas que o aviso foi dado.
  Future<void> arquivarMensagem(String uid, String mensagemId) {
    return _mensagens(uid).doc(mensagemId).update({'arquivadaPeloAluno': true});
  }

  /// O staff apaga de vez — some dos dois lados. É o caminho pra quem
  /// mandou errado (editar não existe de propósito: o aluno pode já ter
  /// lido o texto antigo).
  Future<void> apagarMensagem(String uid, String mensagemId) {
    return _mensagens(uid).doc(mensagemId).delete();
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
  ///
  /// Também renova a matrícula ativa até o novo vencimento (ver
  /// [renovarMatriculaPorPagamento]). Devolve `false` se o aluno não tem
  /// matrícula ativa — o pagamento é registrado do mesmo jeito, mas a
  /// catraca não vai liberar, e a tela avisa a recepção.
  Future<bool> marcarPagamentoRecebido(
    String uid, {
    required DateTime? vencimentoAtual,
    required String staffUid,
    required String staffNome,
  }) async {
    final base = vencimentoAtual ?? DateTime.now();
    final novoVencimento = adicionarUmMes(base);

    await _alunos.doc(uid).set({
      'proximoVencimento': Timestamp.fromDate(novoVencimento),
    }, SetOptions(merge: true));
    final temMatricula = await renovarMatriculaPorPagamento(_firestore, uid, novoVencimento);

    await _pagamentos(uid).add(
      Pagamento(
        registradoEm: DateTime.now(),
        vencimentoAnterior: vencimentoAtual,
        novoVencimento: novoVencimento,
        registradoPorUid: staffUid,
        registradoPorNome: staffNome,
      ).toFirestore(),
    );
    return temMatricula;
  }

  /// Bloqueio manual de acesso (ficha → Gerenciar acesso): o aluno fica
  /// barrado na catraca e no app até desbloquear, mesmo com a mensalidade
  /// em dia. Guarda o motivo e quem bloqueou.
  Future<void> bloquearAluno(
    String uid, {
    required String motivo,
    required String staffUid,
    required String staffNome,
  }) {
    return _alunos.doc(uid).set({
      'bloqueado': true,
      'motivoBloqueio': motivo.trim(),
      'bloqueadoEm': FieldValue.serverTimestamp(),
      'bloqueadoPorUid': staffUid,
      'bloqueadoPorNome': staffNome,
    }, SetOptions(merge: true));
  }

  Future<void> desbloquearAluno(
    String uid, {
    required String staffUid,
    required String staffNome,
  }) {
    return _alunos.doc(uid).set({
      'bloqueado': false,
      'desbloqueadoEm': FieldValue.serverTimestamp(),
      'desbloqueadoPorUid': staffUid,
      'desbloqueadoPorNome': staffNome,
    }, SetOptions(merge: true));
  }

  /// Inativação manual (aluno saiu da academia): vai pra lista de
  /// Inativos e fica barrado na catraca e no app. Volta com
  /// [receberMensalidade] usando `reativar: true` (reativar = receber).
  Future<void> inativarAluno(
    String uid, {
    String? motivo,
    required String staffUid,
    required String staffNome,
  }) {
    return _alunos.doc(uid).set({
      'ativo': false,
      'dataInativacao': FieldValue.serverTimestamp(),
      'motivoInativacao': (motivo == null || motivo.trim().isEmpty) ? null : motivo.trim(),
      'inativadoPorUid': staffUid,
      'inativadoPorNome': staffNome,
    }, SetOptions(merge: true));
  }

  /// "Receber mensalidade": num passo só, com tudo registrado.
  ///
  /// - cria a cobrança já paga em Contas a receber (é o que o relatório
  ///   financeiro soma), ligada à matrícula ativa;
  /// - se houver caixa aberto, lança a entrada no caixa;
  /// - avança o vencimento 1 mês a partir do vencimento atual (pagar
  ///   atrasado não muda o dia de vencimento do aluno);
  /// - renova a matrícula ativa até o novo vencimento (modelo A);
  /// - guarda o histórico em `pagamentos`, agora com valor e forma.
  ///
  /// Tudo numa transação: ou grava tudo, ou nada. O caixa e as matrículas
  /// são localizados antes (transação só lê documento por documento) e
  /// relidos dentro dela.
  Future<RecebimentoMensalidade> receberMensalidade(
    String uid, {
    required DateTime? vencimentoAtual,
    required double valor,
    required String formaPagamento,
    required String staffUid,
    required String staffNome,
    String? alunoNome,
    bool reativar = false,
  }) async {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    // Reativando, o novo ciclo começa hoje (nada de cobrar o tempo em que
    // ficou inativo); senão, a partir do vencimento atual.
    final vencimentoPago = reativar ? hoje : (vencimentoAtual ?? hoje);
    final novoVencimento = adicionarUmMes(vencimentoPago);

    final caixaSnap = await _firestore
        .collection('caixas')
        .where('status', isEqualTo: 'aberto')
        .limit(1)
        .get();
    final caixaRef = caixaSnap.docs.isEmpty ? null : caixaSnap.docs.first.reference;
    final ativasSnap = await _matriculas(uid).where('status', isEqualTo: 'ativa').get();

    final contaRef = _contasReceber(uid).doc();
    final pagamentoRef = _pagamentos(uid).doc();
    final movRef = caixaRef?.collection('movimentacoes').doc();
    final dataTexto =
        '${vencimentoPago.day.toString().padLeft(2, '0')}/${vencimentoPago.month.toString().padLeft(2, '0')}';

    return _firestore.runTransaction<RecebimentoMensalidade>((transaction) async {
      // Leituras antes de qualquer escrita (regra do Firestore).
      final caixa = caixaRef == null ? null : await transaction.get(caixaRef);
      final matriculas = [for (final doc in ativasSnap.docs) await transaction.get(doc.reference)];

      final caixaAberto = caixa != null && caixa.exists && caixa.data()?['status'] == 'aberto';
      final ativas = matriculas
          .where((doc) => doc.exists && doc.data()?['status'] == 'ativa')
          .toList();

      transaction.set(
        contaRef,
        ContaReceber(
          alunoId: uid,
          matriculaId: ativas.isEmpty ? null : ativas.first.id,
          descricao: 'Mensalidade (vencimento $dataTexto)',
          valorOriginal: valor,
          valorPago: valor,
          vencimento: vencimentoPago,
          dataPagamento: agora,
          status: StatusContaReceber.pago,
          formaPagamento: formaPagamento,
          criadoPorUid: staffUid,
          criadoPorNome: staffNome,
          recebidoPorUid: staffUid,
          recebidoPorNome: staffNome,
          movimentacaoCaixaId: caixaAberto ? movRef!.id : null,
        ).toFirestore(),
      );

      if (caixaAberto) {
        transaction.set(
          movRef!,
          CaixaMovimentacao(
            tipo: TipoMovimentacaoCaixa.recebimento,
            valor: valor,
            formaPagamento: formaPagamento,
            descricao: alunoNome == null ? 'Mensalidade' : 'Mensalidade — $alunoNome',
            contaReceberAlunoId: uid,
            contaReceberId: contaRef.id,
            staffUid: staffUid,
            staffNome: staffNome,
          ).toFirestore(),
        );
      }

      transaction.set(_alunos.doc(uid), {
        'proximoVencimento': Timestamp.fromDate(novoVencimento),
        if (reativar) ...{
          'ativo': true,
          'dataReativacao': Timestamp.fromDate(agora),
          'reativadoPorUid': staffUid,
          'reativadoPorNome': staffNome,
        },
      }, SetOptions(merge: true));

      for (final matricula in ativas) {
        final atual = matricula.data()?['dataVencimento'];
        final vence = atual is Timestamp ? atual.toDate() : null;
        if (vence != null && !vence.isBefore(novoVencimento)) continue;
        transaction.update(matricula.reference, {
          'dataVencimento': Timestamp.fromDate(novoVencimento),
          'renovadaPorPagamentoEm': FieldValue.serverTimestamp(),
          'atualizadoEm': FieldValue.serverTimestamp(),
        });
      }

      transaction.set(
        pagamentoRef,
        Pagamento(
          registradoEm: agora,
          vencimentoAnterior: vencimentoAtual,
          novoVencimento: novoVencimento,
          registradoPorUid: staffUid,
          registradoPorNome: staffNome,
          valor: valor,
          formaPagamento: formaPagamento,
          contaReceberId: contaRef.id,
        ).toFirestore(),
      );

      return RecebimentoMensalidade(
        novoVencimento: novoVencimento,
        temMatricula: ativas.isNotEmpty,
        lancadoNoCaixa: caixaAberto,
      );
    });
  }

  /// Define o primeiro vencimento de um aluno que ainda nao tem nenhum
  /// configurado, sem que isso conte como um pagamento recebido.
  Future<void> definirVencimentoInicial(String uid, DateTime vencimento) {
    return _alunos.doc(uid).set({
      'proximoVencimento': Timestamp.fromDate(vencimento),
    }, SetOptions(merge: true));
  }

  /// Reativa um aluno que ficou `Aluno.ativo == false` pela automação de
  /// inadimplência (30 dias de atraso, ver `functions/lib/inadimplencia.js`)
  /// — ou por qualquer outro motivo de inativação manual. Encerra o ciclo
  /// de inadimplência anterior e começa um novo: `proximoVencimento` é
  /// recalculado a partir de HOJE (1 mês à frente), nunca a partir do
  /// vencimento antigo — os meses em que o aluno ficou afastado nunca são
  /// cobrados retroativamente. `dataInativacao` é preservada como
  /// histórico (não apagada); só `dataReativacao` é atualizada.
  Future<void> reativarAluno(
    String uid, {
    required String staffUid,
    required String staffNome,
  }) async {
    final agora = DateTime.now();
    await _alunos.doc(uid).set({
      'ativo': true,
      'dataReativacao': Timestamp.fromDate(agora),
      'proximoVencimento': Timestamp.fromDate(adicionarUmMes(agora)),
      'reativadoPorUid': staffUid,
      'reativadoPorNome': staffNome,
    }, SetOptions(merge: true));
  }

  /// Define o vencimento de vários alunos de uma vez — usado pra preencher
  /// os alunos antigos, cadastrados antes do vencimento automático (ver
  /// `vencimentoParaAlunoAntigo`). Não conta como pagamento recebido.
  Future<void> definirVencimentosEmLote(Map<String, DateTime> vencimentoPorUid) async {
    final itens = vencimentoPorUid.entries.toList();
    // Lote do Firestore aceita no máximo 500 escritas.
    for (var i = 0; i < itens.length; i += 400) {
      final lote = _firestore.batch();
      for (final item in itens.skip(i).take(400)) {
        lote.set(_alunos.doc(item.key), {
          'proximoVencimento': Timestamp.fromDate(item.value),
          'diaVencimento': item.value.day,
        }, SetOptions(merge: true));
      }
      await lote.commit();
    }
  }

  /// Avança `Aluno.proximoVencimento` em 1 mês a partir de [vencimentoOriginal]
  /// (o vencimento da cobrança que acabou de ser paga) — usado por
  /// [registrarRecebimento] só quando a cobrança recebida está vinculada a
  /// uma matrícula (mensalidade), pra que confirmar o pagamento pela tela
  /// "Contas a Receber" também libere o acesso do aluno — antes disso só a
  /// seção "Mensalidade" da aba Dados fazia esse avanço, deixando as duas
  /// telas dessincronizadas. `CaixaService.registrarRecebimentoContaReceber`
  /// faz o mesmo avanço (mesma função [adicionarUmMes]), só que dentro da
  /// própria transação do caixa em vez de chamar este método privado.
  Future<void> _avancarProximoVencimento(String uid, DateTime vencimentoOriginal) async {
    final novoVencimento = adicionarUmMes(vencimentoOriginal);
    await _alunos.doc(uid).set({
      'proximoVencimento': Timestamp.fromDate(novoVencimento),
    }, SetOptions(merge: true));
    // Pagou a mensalidade: a matrícula acompanha (ver
    // renovarMatriculaPorPagamento).
    await renovarMatriculaPorPagamento(_firestore, uid, novoVencimento);
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
    String? planoId,
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
          planoId: planoId ?? '',
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
  ///
  /// Se [matriculaId] e [vencimentoOriginal] forem informados (a cobrança
  /// paga está vinculada a uma matrícula — ver `ContaReceberFormScreen`),
  /// também avança `Aluno.proximoVencimento`, liberando o acesso do aluno
  /// no mesmo passo. Cobranças avulsas (produto, sessão extra etc., sem
  /// matrícula vinculada) nunca mexem no vencimento — só a mensalidade
  /// controla o acesso.
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
    String? matriculaId,
    DateTime? vencimentoOriginal,
  }) async {
    await _contasReceber(alunoUid).doc(contaId).set({
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

    if (matriculaId != null && vencimentoOriginal != null) {
      await _avancarProximoVencimento(alunoUid, vencimentoOriginal);
    }
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
      diaSemana: treino.diaSemana,
      objetivo: treino.objetivo,
      vigenciaAte: treino.vigenciaAte,
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

  /// Histórico de presença/frequência do aluno, mais recente primeiro —
  /// nunca inclui a ficha prescrita em si (ver `watchTreinos`), só os
  /// registros de realizado/falta que o staff confirmou.
  Stream<List<HistoricoTreino>> watchHistoricoTreinos(String uid) {
    return _historicoTreinos(uid)
        .orderBy('data', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => HistoricoTreino.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Registra presença/falta de um treino numa data — só quem tem
  /// `criarTreinos`/`editarTreinos` pode chamar isso (reforçado em
  /// `firestore.rules`); o aluno nunca grava o próprio histórico.
  Future<String> registrarHistoricoTreino(
    String uid,
    HistoricoTreino registro, {
    required String staffUid,
    required String staffNome,
  }) async {
    final dados = registro.toFirestore();
    dados['registradoPorUid'] = staffUid;
    dados['registradoPorNome'] = staffNome;
    final ref = await _historicoTreinos(uid).add(dados);
    return ref.id;
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

      // Vencimento automático: 1 mês depois do dia do cadastro (ver
      // [primeiroVencimento]).
      final vencimento = primeiroVencimento(dataInicio ?? DateTime.now());

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
          diaVencimento: vencimento.day,
          proximoVencimento: vencimento,
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

/// O que aconteceu num [AlunoService.receberMensalidade] — a tela usa pra
/// avisar a recepção (sem matrícula a catraca não libera; sem caixa
/// aberto o valor não entra no caixa).
class RecebimentoMensalidade {
  const RecebimentoMensalidade({
    required this.novoVencimento,
    required this.temMatricula,
    required this.lancadoNoCaixa,
  });

  final DateTime novoVencimento;
  final bool temMatricula;
  final bool lancadoNoCaixa;
}
