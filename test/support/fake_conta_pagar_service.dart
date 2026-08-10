import 'package:gymextreme_app/models/conta_pagar.dart';
import 'package:gymextreme_app/services/conta_pagar_service.dart';

/// Dublê de teste do [ContaPagarService] — mesmo padrão de
/// [FakeCaixaService]: implementa a mesma interface pública sem tocar o
/// Firestore de verdade.
class FakeContaPagarService implements ContaPagarService {
  FakeContaPagarService({List<ContaPagar> contas = const []}) : contas = List.of(contas);

  List<ContaPagar> contas;

  String? ultimaContaCriadaId;
  String? ultimaContaAtualizadaId;
  String? ultimaContaExcluidaId;
  String? ultimaContaPagaId;

  int _proximoId = 1;

  ContaPagar? _acharPorId(String id) {
    for (final conta in contas) {
      if (conta.id == id) return conta;
    }
    return null;
  }

  void _substituir(ContaPagar atualizada) {
    contas = [
      for (final conta in contas) if (conta.id == atualizada.id) atualizada else conta,
    ];
  }

  @override
  Stream<List<ContaPagar>> watchContasPagar() => Stream.value(contas);

  @override
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
    final id = 'conta-pagar-${_proximoId++}';
    final conta = ContaPagar(
      id: id,
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
    );
    contas = [...contas, conta];
    ultimaContaCriadaId = id;
    return id;
  }

  @override
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
  }) async {
    final atual = _acharPorId(contaId);
    if (atual == null) {
      throw ContaPagarServiceException('Conta a pagar não encontrada.');
    }
    _substituir(
      atual.copyWith(
        fornecedor: fornecedor,
        descricao: descricao,
        categoria: categoria,
        valorOriginal: valorOriginal,
        desconto: desconto,
        jurosMulta: jurosMulta,
        vencimento: vencimento,
        observacao: observacao,
      ),
    );
    ultimaContaAtualizadaId = contaId;
  }

  @override
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
    final atual = _acharPorId(contaId);
    if (atual == null) {
      throw ContaPagarServiceException('Conta a pagar não encontrada.');
    }
    if (atual.status == StatusContaPagar.pago) {
      throw ContaPagarServiceException('Esta conta já foi paga.');
    }
    _substituir(
      atual.copyWith(
        status: StatusContaPagar.pago,
        valorPago: valorPago,
        desconto: desconto,
        jurosMulta: jurosMulta,
        dataPagamento: dataPagamento,
        formaPagamento: formaPagamento,
        observacao: observacao,
        pagoPorUid: staffUid,
        pagoPorNome: staffNome,
      ),
    );
    ultimaContaPagaId = contaId;
  }

  @override
  Future<void> excluirContaPagar(String contaId) async {
    final atual = _acharPorId(contaId);
    if (atual == null) {
      throw ContaPagarServiceException('Conta a pagar não encontrada.');
    }
    _substituir(atual.copyWith(status: StatusContaPagar.cancelado));
    ultimaContaExcluidaId = contaId;
  }
}
