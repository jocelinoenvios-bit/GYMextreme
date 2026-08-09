import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/caixa.dart';
import '../models/caixa_movimentacao.dart';
import '../models/conta_receber.dart';

/// Controle de caixa da academia (coleção `caixas`, nível de academia —
/// não pertence a nenhum aluno, mesmo padrão de `PlanoService`). Cada
/// abertura é seu próprio documento; as movimentações vivem em
/// `caixas/{id}/movimentacoes`.
///
/// Deliberadamente não fica dentro de `AlunoService`: ao contrário de
/// `Matricula`/`ContaReceber` (que pertencem a UM aluno), o caixa é uma
/// sessão operacional única compartilhada por toda a equipe.
class CaixaService {
  CaixaService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _caixas =>
      _firestore.collection('caixas');

  CollectionReference<Map<String, dynamic>> _movimentacoes(String caixaId) =>
      _caixas.doc(caixaId).collection('movimentacoes');

  /// O caixa aberto agora, se houver algum — nunca mais que um por vez
  /// (ver [abrirCaixa]). `null` quando nenhum caixa está aberto.
  Stream<Caixa?> watchCaixaAberto() {
    return _caixas
        .where('status', isEqualTo: StatusCaixa.aberto.name)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          final doc = snapshot.docs.first;
          return Caixa.fromFirestore(doc.id, doc.data());
        });
  }

  /// Histórico de todos os caixas (abertos e fechados), mais recente
  /// primeiro. Sem `.orderBy()` no Firestore de propósito — mesmo motivo
  /// de `AlunoService.watchAlunos()`: evita depender de índice composto;
  /// a lista de caixas de uma academia é pequena o bastante pra ordenar
  /// no cliente.
  Stream<List<Caixa>> watchHistorico() {
    return _caixas.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => Caixa.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort(
              (a, b) => (b.abertoEm ?? DateTime(0)).compareTo(
                a.abertoEm ?? DateTime(0),
              ),
            ),
    );
  }

  /// Movimentações de UM caixa, mais recente primeiro.
  Stream<List<CaixaMovimentacao>> watchMovimentacoes(String caixaId) {
    return _movimentacoes(caixaId).snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => CaixaMovimentacao.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort(
              (a, b) => (b.criadoEm ?? DateTime(0)).compareTo(
                a.criadoEm ?? DateTime(0),
              ),
            ),
    );
  }

  /// Abre um caixa novo. Lança [CaixaServiceException] se já existir
  /// outro aberto — nunca dois caixas abertos ao mesmo tempo, mesma
  /// técnica de transação + revalidação usada em
  /// `AlunoService.criarMatricula` pra "só uma matrícula ativa por vez".
  Future<String> abrirCaixa({
    required double valorInicial,
    required String staffUid,
    required String staffNome,
  }) async {
    final abertosSnap = await _caixas
        .where('status', isEqualTo: StatusCaixa.aberto.name)
        .get();

    return _firestore.runTransaction<String>((transaction) async {
      final frescos = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final doc in abertosSnap.docs) {
        frescos.add(await transaction.get(doc.reference));
      }
      for (final fresco in frescos) {
        if (fresco.exists &&
            fresco.data()?['status'] == StatusCaixa.aberto.name) {
          throw CaixaServiceException(
            'Já existe um caixa aberto. Feche-o antes de abrir outro.',
          );
        }
      }

      final ref = _caixas.doc();
      transaction.set(
        ref,
        Caixa(
          valorInicial: valorInicial,
          abertoPorUid: staffUid,
          abertoPorNome: staffNome,
        ).toFirestore(),
      );
      return ref.id;
    });
  }

  /// Registra uma movimentação avulsa — suprimento, retirada ou ajuste.
  /// Para recebimento de cobrança use sempre [registrarRecebimentoContaReceber],
  /// nunca este método diretamente (por isso `tipo == recebimento` é
  /// rejeitado aqui).
  ///
  /// [valor] é a MAGNITUDE positiva digitada pelo usuário pra
  /// suprimento/retirada — o sinal certo é aplicado aqui dentro (retirada
  /// sempre subtrai do saldo). Pra `ajuste`, [valor] já deve vir
  /// assinado (pode ser negativo), já que uma correção pode ir pros dois
  /// lados.
  Future<String> registrarMovimentacao(
    String caixaId, {
    required TipoMovimentacaoCaixa tipo,
    required double valor,
    String? formaPagamento,
    String? descricao,
    required String staffUid,
    required String staffNome,
  }) async {
    if (tipo == TipoMovimentacaoCaixa.recebimento) {
      throw CaixaServiceException(
        'Recebimentos de cobrança devem usar registrarRecebimentoContaReceber.',
      );
    }

    await _exigirCaixaAberto(caixaId);

    final valorComSinal = switch (tipo) {
      TipoMovimentacaoCaixa.suprimento => valor.abs(),
      TipoMovimentacaoCaixa.retirada => -valor.abs(),
      TipoMovimentacaoCaixa.ajuste => valor,
      TipoMovimentacaoCaixa.recebimento =>
        valor, // inalcançável — bloqueado acima
    };

    final ref = await _movimentacoes(caixaId).add(
      CaixaMovimentacao(
        tipo: tipo,
        valor: valorComSinal,
        formaPagamento: formaPagamento,
        descricao: descricao,
        staffUid: staffUid,
        staffNome: staffNome,
      ).toFirestore(),
    );
    return ref.id;
  }

  /// Registra o recebimento de uma `ContaReceber` E a movimentação de
  /// caixa correspondente, atomicamente (mesma transação) — usado quando
  /// existe um caixa aberto no momento do recebimento
  /// (`RegistrarRecebimentoScreen` decide isso olhando
  /// [watchCaixaAberto]). Sem caixa aberto, o recebimento passa por
  /// `AlunoService.registrarRecebimento` sozinho, sem tocar em nenhum
  /// caixa.
  ///
  /// Trava contra duplicidade: se a `ContaReceber` já tiver
  /// `movimentacaoCaixaId` preenchido, lança [CaixaServiceException] em
  /// vez de criar uma segunda movimentação pro mesmo recebimento. Também
  /// recusa se o caixa já estiver fechado.
  Future<String> registrarRecebimentoContaReceber({
    required String caixaId,
    required String alunoUid,
    required String contaReceberId,
    required double valorPago,
    required double desconto,
    required double jurosMulta,
    required DateTime dataPagamento,
    String? formaPagamento,
    String? observacao,
    required String staffUid,
    required String staffNome,
  }) {
    final contaRef = _firestore
        .collection('alunos')
        .doc(alunoUid)
        .collection('contasReceber')
        .doc(contaReceberId);
    final caixaRef = _caixas.doc(caixaId);
    final movRef = _movimentacoes(caixaId).doc();

    return _firestore.runTransaction<String>((transaction) async {
      // Leituras antes de qualquer escrita (regra do Firestore).
      final contaSnap = await transaction.get(contaRef);
      final caixaSnap = await transaction.get(caixaRef);

      if (!contaSnap.exists) {
        throw CaixaServiceException('Cobrança não encontrada.');
      }
      if (contaSnap.data()?['movimentacaoCaixaId'] != null) {
        throw CaixaServiceException(
          'Esta cobrança já foi registrada no caixa.',
        );
      }
      if (!caixaSnap.exists ||
          StatusCaixa.fromFirestoreValue(
                caixaSnap.data()?['status'] as String?,
              ) !=
              StatusCaixa.aberto) {
        throw CaixaServiceException('Este caixa não está aberto.');
      }

      transaction.update(contaRef, {
        'status': StatusContaReceber.pago.name,
        'valorPago': valorPago,
        'desconto': desconto,
        'jurosMulta': jurosMulta,
        'dataPagamento': Timestamp.fromDate(dataPagamento),
        'formaPagamento': formaPagamento,
        'observacao': observacao,
        'recebidoPorUid': staffUid,
        'recebidoPorNome': staffNome,
        'movimentacaoCaixaId': movRef.id,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      transaction.set(
        movRef,
        CaixaMovimentacao(
          tipo: TipoMovimentacaoCaixa.recebimento,
          valor: valorPago,
          formaPagamento: formaPagamento,
          descricao: observacao,
          contaReceberAlunoId: alunoUid,
          contaReceberId: contaReceberId,
          staffUid: staffUid,
          staffNome: staffNome,
        ).toFirestore(),
      );

      return movRef.id;
    });
  }

  /// Fecha o caixa: calcula o saldo esperado a partir de todas as
  /// movimentações atuais, grava a diferença em relação ao valor
  /// contado, e marca `status: fechado`. Depois disso o documento nunca
  /// mais é alterado por nenhum outro método deste serviço — ver a
  /// checagem de `StatusCaixa.fechado` em [_exigirCaixaAberto] e no
  /// início deste método.
  Future<void> fecharCaixa(
    String caixaId, {
    required double valorContado,
    String? observacao,
    required String staffUid,
    required String staffNome,
  }) async {
    final caixaDoc = await _caixas.doc(caixaId).get();
    final data = caixaDoc.data();
    if (data == null) {
      throw CaixaServiceException('Caixa não encontrado.');
    }
    final caixa = Caixa.fromFirestore(caixaDoc.id, data);
    if (caixa.status == StatusCaixa.fechado) {
      throw CaixaServiceException('Este caixa já está fechado.');
    }

    final movimentacoesSnap = await _movimentacoes(caixaId).get();
    final totalMovimentacoes = movimentacoesSnap.docs.fold<double>(
      0,
      (soma, doc) => soma + ((doc.data()['valor'] as num?)?.toDouble() ?? 0),
    );
    final valorEsperado = caixa.valorInicial + totalMovimentacoes;
    final diferenca = valorContado - valorEsperado;

    await _caixas.doc(caixaId).set({
      'status': StatusCaixa.fechado.name,
      'valorContado': valorContado,
      'valorEsperadoNoFechamento': valorEsperado,
      'diferenca': diferenca,
      'fechadoPorUid': staffUid,
      'fechadoPorNome': staffNome,
      'fechadoEm': FieldValue.serverTimestamp(),
      'observacaoFechamento': observacao,
    }, SetOptions(merge: true));
  }

  Future<void> _exigirCaixaAberto(String caixaId) async {
    final doc = await _caixas.doc(caixaId).get();
    final data = doc.data();
    if (data == null ||
        StatusCaixa.fromFirestoreValue(data['status'] as String?) !=
            StatusCaixa.aberto) {
      throw CaixaServiceException('Este caixa não está aberto.');
    }
  }
}

/// Erro de operação de caixa com mensagem pronta pra exibir ao usuário.
class CaixaServiceException implements Exception {
  CaixaServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
