import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/conta_pagar.dart';

/// Contas a pagar da academia (coleção `contasPagar`, nível de academia —
/// não pertence a nenhum aluno, mesmo padrão de `PlanoService`/
/// `CaixaService`, ao contrário de `ContaReceber`, que pertence a um
/// aluno específico).
///
/// Integração com o Caixa: quando existe um caixa aberto no momento do
/// pagamento, ele é registrado atomicamente via
/// `CaixaService.registrarPagamentoContaPagar` (que também toca esta
/// coleção, dentro da mesma transação). [registrarPagamentoSemCaixa]
/// cobre só o caminho sem nenhum caixa aberto.
class ContaPagarService {
  ContaPagarService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _contasPagar =>
      _firestore.collection('contasPagar');

  /// Todas as contas a pagar, vencimento mais próximo primeiro. Sem
  /// `.orderBy()`/`.where()` no Firestore de propósito — mesmo motivo de
  /// `AlunoService.watchTodasContasReceber()`: evita depender de índice
  /// composto; a tela filtra (período, vencimento, status, fornecedor,
  /// categoria) e ordena no cliente.
  Stream<List<ContaPagar>> watchContasPagar() {
    return _contasPagar.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => ContaPagar.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => a.vencimento.compareTo(b.vencimento)),
    );
  }

  /// Lança uma despesa nova — sempre nasce `pendente`, nunca já paga
  /// (isso passa por [registrarPagamentoSemCaixa] ou
  /// `CaixaService.registrarPagamentoContaPagar`).
  Future<String> criarContaPagar({
    required String fornecedor,
    required String descricao,
    required String categoria,
    required double valorOriginal,
    double desconto = 0,
    double jurosMulta = 0,
    required DateTime vencimento,
    String? formaPagamento,
    String? observacao,
    required String staffUid,
    required String staffNome,
  }) async {
    final ref = await _contasPagar.add(
      ContaPagar(
        fornecedor: fornecedor,
        descricao: descricao,
        categoria: categoria,
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

  /// Edita os dados básicos de uma despesa (fornecedor, descrição,
  /// categoria, valor, desconto, juros/multa, vencimento, observação).
  /// Nunca mexe em status/valorPago/dataPagamento/responsável pelo
  /// pagamento — isso é sempre [registrarPagamentoSemCaixa] ou
  /// `CaixaService.registrarPagamentoContaPagar`, nunca esta função.
  Future<void> atualizarContaPagar(
    String contaId, {
    required String fornecedor,
    required String descricao,
    required String categoria,
    required double valorOriginal,
    required double desconto,
    required double jurosMulta,
    required DateTime vencimento,
    String? observacao,
  }) {
    return _contasPagar.doc(contaId).set({
      'fornecedor': fornecedor,
      'descricao': descricao,
      'categoria': categoria,
      'valorOriginal': valorOriginal,
      'desconto': desconto,
      'jurosMulta': jurosMulta,
      'vencimento': Timestamp.fromDate(vencimento),
      'observacao': observacao,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Registra o pagamento SEM tocar em nenhum caixa — usado quando não há
  /// caixa aberto no momento (ver `CaixaService.registrarPagamentoContaPagar`
  /// para o caminho integrado, escolhido pela tela olhando
  /// `CaixaService.watchCaixaAberto`). Recusa pagar de novo uma conta que
  /// já está paga.
  Future<void> registrarPagamentoSemCaixa(
    String contaId, {
    required double valorPago,
    required double desconto,
    required double jurosMulta,
    required DateTime dataPagamento,
    String? formaPagamento,
    String? observacao,
    required String staffUid,
    required String staffNome,
  }) async {
    final snap = await _contasPagar.doc(contaId).get();
    final data = snap.data();
    if (data == null) {
      throw ContaPagarServiceException('Conta a pagar não encontrada.');
    }
    if (StatusContaPagar.fromFirestoreValue(data['status'] as String?) ==
        StatusContaPagar.pago) {
      throw ContaPagarServiceException('Esta conta já foi paga.');
    }

    await _contasPagar.doc(contaId).set({
      'status': StatusContaPagar.pago.name,
      'valorPago': valorPago,
      'desconto': desconto,
      'jurosMulta': jurosMulta,
      'dataPagamento': Timestamp.fromDate(dataPagamento),
      'formaPagamento': formaPagamento,
      'observacao': observacao,
      'pagoPorUid': staffUid,
      'pagoPorNome': staffNome,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// "Exclui" uma despesa sem apagar o documento — marca `cancelado`,
  /// mesmo padrão de `AlunoService.excluirContaReceber`/
  /// `PlanoService.excluirPlano` (preserva o histórico financeiro, nunca
  /// reaproveita o registro).
  Future<void> excluirContaPagar(String contaId) {
    return _contasPagar.doc(contaId).set({
      'status': StatusContaPagar.cancelado.name,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

/// Erro de operação de conta a pagar com mensagem pronta pra exibir ao
/// usuário.
class ContaPagarServiceException implements Exception {
  ContaPagarServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
