import 'package:gymextreme_app/models/caixa.dart';
import 'package:gymextreme_app/models/caixa_movimentacao.dart';
import 'package:gymextreme_app/services/caixa_service.dart';

/// Dublê de teste do [CaixaService] — mesmo padrão de [FakePlanoService]:
/// implementa a mesma interface pública sem tocar o Firestore de verdade.
class FakeCaixaService implements CaixaService {
  FakeCaixaService({this.caixaAberto, this.historico = const [], this.movimentacoes = const []});

  Caixa? caixaAberto;
  List<Caixa> historico;
  List<CaixaMovimentacao> movimentacoes;

  /// Força `registrarRecebimentoContaReceber` a lançar
  /// [CaixaServiceException] — simula o caso "cobrança já registrada no
  /// caixa" sem precisar simular todo o estado da `ContaReceber`.
  bool lancarErroAoRegistrarRecebimento = false;

  double? ultimoValorInicialAbertura;
  String? ultimoCaixaFechadoId;
  double? ultimoValorContadoFechamento;
  CaixaMovimentacao? ultimaMovimentacaoRegistrada;
  ({String caixaId, String alunoUid, String contaReceberId, double valorPago})?
  ultimoRecebimentoViaCaixa;

  @override
  Stream<Caixa?> watchCaixaAberto() => Stream.value(caixaAberto);

  @override
  Stream<List<Caixa>> watchHistorico() => Stream.value(historico);

  @override
  Stream<List<CaixaMovimentacao>> watchMovimentacoes(String caixaId) =>
      Stream.value(movimentacoes);

  @override
  Future<String> abrirCaixa({
    required double valorInicial,
    required String staffUid,
    required String staffNome,
  }) async {
    if (caixaAberto != null) {
      throw CaixaServiceException('Já existe um caixa aberto. Feche-o antes de abrir outro.');
    }
    const id = 'caixa-1';
    ultimoValorInicialAbertura = valorInicial;
    caixaAberto = Caixa(
      id: id,
      valorInicial: valorInicial,
      abertoPorUid: staffUid,
      abertoPorNome: staffNome,
      abertoEm: DateTime.now(),
    );
    return id;
  }

  @override
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
    if (caixaAberto == null || caixaAberto!.id != caixaId) {
      throw CaixaServiceException('Este caixa não está aberto.');
    }

    final valorComSinal = switch (tipo) {
      TipoMovimentacaoCaixa.suprimento => valor.abs(),
      TipoMovimentacaoCaixa.retirada => -valor.abs(),
      TipoMovimentacaoCaixa.ajuste => valor,
      TipoMovimentacaoCaixa.recebimento => valor,
    };

    final mov = CaixaMovimentacao(
      id: 'mov-${movimentacoes.length + 1}',
      tipo: tipo,
      valor: valorComSinal,
      formaPagamento: formaPagamento,
      descricao: descricao,
      staffUid: staffUid,
      staffNome: staffNome,
      criadoEm: DateTime.now(),
    );
    movimentacoes = [...movimentacoes, mov];
    ultimaMovimentacaoRegistrada = mov;
    return mov.id!;
  }

  @override
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
  }) async {
    if (lancarErroAoRegistrarRecebimento) {
      throw CaixaServiceException('Esta cobrança já foi registrada no caixa.');
    }
    if (caixaAberto == null || caixaAberto!.id != caixaId) {
      throw CaixaServiceException('Este caixa não está aberto.');
    }

    final mov = CaixaMovimentacao(
      id: 'mov-${movimentacoes.length + 1}',
      tipo: TipoMovimentacaoCaixa.recebimento,
      valor: valorPago,
      formaPagamento: formaPagamento,
      descricao: observacao,
      contaReceberAlunoId: alunoUid,
      contaReceberId: contaReceberId,
      staffUid: staffUid,
      staffNome: staffNome,
      criadoEm: DateTime.now(),
    );
    movimentacoes = [...movimentacoes, mov];
    ultimaMovimentacaoRegistrada = mov;
    ultimoRecebimentoViaCaixa = (
      caixaId: caixaId,
      alunoUid: alunoUid,
      contaReceberId: contaReceberId,
      valorPago: valorPago,
    );
    return mov.id!;
  }

  @override
  Future<void> fecharCaixa(
    String caixaId, {
    required double valorContado,
    String? observacao,
    required String staffUid,
    required String staffNome,
  }) async {
    if (caixaAberto == null || caixaAberto!.id != caixaId) {
      throw CaixaServiceException('Este caixa já está fechado.');
    }

    final totalMovimentacoes = movimentacoes.fold<double>(0, (soma, m) => soma + m.valor);
    final valorEsperado = caixaAberto!.valorInicial + totalMovimentacoes;

    ultimoCaixaFechadoId = caixaId;
    ultimoValorContadoFechamento = valorContado;

    final fechado = Caixa(
      id: caixaAberto!.id,
      valorInicial: caixaAberto!.valorInicial,
      status: StatusCaixa.fechado,
      abertoPorUid: caixaAberto!.abertoPorUid,
      abertoPorNome: caixaAberto!.abertoPorNome,
      abertoEm: caixaAberto!.abertoEm,
      valorContado: valorContado,
      valorEsperadoNoFechamento: valorEsperado,
      diferenca: valorContado - valorEsperado,
      fechadoPorUid: staffUid,
      fechadoPorNome: staffNome,
      fechadoEm: DateTime.now(),
      observacaoFechamento: observacao,
    );
    historico = [...historico, fechado];
    caixaAberto = null;
  }
}
