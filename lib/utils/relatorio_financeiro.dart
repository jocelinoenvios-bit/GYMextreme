import '../models/caixa_movimentacao.dart';
import '../models/conta_pagar.dart';
import '../models/conta_receber.dart';
import 'status_conta_pagar.dart';
import 'status_conta_receber.dart';

/// Totais de um conjunto de [ContaReceber] — usado pelo relatório
/// financeiro, sempre calculado sobre uma lista já filtrada (por período,
/// por status etc.), nunca lendo o Firestore diretamente.
class TotaisContasReceber {
  const TotaisContasReceber({
    required this.quantidade,
    required this.totalEmAberto,
    required this.totalVencido,
    required this.totalPago,
  });

  final int quantidade;
  final double totalEmAberto;
  final double totalVencido;
  final double totalPago;
}

TotaisContasReceber calcularTotaisContasReceber(
  List<ContaReceber> contas, {
  DateTime? hoje,
}) {
  var totalEmAberto = 0.0;
  var totalVencido = 0.0;
  var totalPago = 0.0;

  for (final conta in contas) {
    final status = calcularStatusEfetivo(conta, hoje: hoje);
    switch (status) {
      case StatusContaReceber.pendente:
        totalEmAberto += conta.saldoDevedor;
      case StatusContaReceber.vencido:
        totalVencido += conta.saldoDevedor;
      case StatusContaReceber.pago:
        totalPago += conta.valorPago ?? 0;
      case StatusContaReceber.cancelado:
        break;
    }
  }

  return TotaisContasReceber(
    quantidade: contas.length,
    totalEmAberto: totalEmAberto,
    totalVencido: totalVencido,
    totalPago: totalPago,
  );
}

/// Mesma ideia de [TotaisContasReceber], para [ContaPagar].
class TotaisContasPagar {
  const TotaisContasPagar({
    required this.quantidade,
    required this.totalEmAberto,
    required this.totalVencido,
    required this.totalPago,
  });

  final int quantidade;
  final double totalEmAberto;
  final double totalVencido;
  final double totalPago;
}

TotaisContasPagar calcularTotaisContasPagar(
  List<ContaPagar> contas, {
  DateTime? hoje,
}) {
  var totalEmAberto = 0.0;
  var totalVencido = 0.0;
  var totalPago = 0.0;

  for (final conta in contas) {
    final status = calcularStatusEfetivoContaPagar(conta, hoje: hoje);
    switch (status) {
      case StatusContaPagar.pendente:
        totalEmAberto += conta.saldoAPagar;
      case StatusContaPagar.vencido:
        totalVencido += conta.saldoAPagar;
      case StatusContaPagar.pago:
        totalPago += conta.valorPago ?? 0;
      case StatusContaPagar.cancelado:
        break;
    }
  }

  return TotaisContasPagar(
    quantidade: contas.length,
    totalEmAberto: totalEmAberto,
    totalVencido: totalVencido,
    totalPago: totalPago,
  );
}

/// Filtra contas a receber cujo [ContaReceber.vencimento] cai dentro de
/// `[de, ate]` (extremos inclusos); um limite `null` não restringe aquele
/// lado do período.
List<ContaReceber> filtrarContasReceberPorPeriodo(
  List<ContaReceber> contas, {
  DateTime? de,
  DateTime? ate,
}) {
  return contas
      .where((c) => _dentroDoPeriodo(c.vencimento, de: de, ate: ate))
      .toList();
}

/// Mesma ideia, para contas a pagar.
List<ContaPagar> filtrarContasPagarPorPeriodo(
  List<ContaPagar> contas, {
  DateTime? de,
  DateTime? ate,
}) {
  return contas
      .where((c) => _dentroDoPeriodo(c.vencimento, de: de, ate: ate))
      .toList();
}

/// Filtra movimentações de caixa cujo [CaixaMovimentacao.criadoEm] cai
/// dentro de `[de, ate]`. Movimentações sem `criadoEm` (não deveria
/// acontecer fora de testes) nunca entram no resultado quando algum
/// limite é informado.
List<CaixaMovimentacao> filtrarMovimentacoesCaixaPorPeriodo(
  List<CaixaMovimentacao> movimentacoes, {
  DateTime? de,
  DateTime? ate,
}) {
  return movimentacoes.where((m) {
    if (m.criadoEm == null) return de == null && ate == null;
    return _dentroDoPeriodo(m.criadoEm!, de: de, ate: ate);
  }).toList();
}

/// Soma assinada de um conjunto de movimentações de caixa — mesmo
/// raciocínio de `CaixaService.fecharCaixa`: soma `valor` sem nenhuma
/// lógica condicional por tipo, já que o valor já vem com o sinal certo.
double somarMovimentacoesCaixa(List<CaixaMovimentacao> movimentacoes) {
  return movimentacoes.fold<double>(0, (soma, m) => soma + m.valor);
}

bool _dentroDoPeriodo(DateTime data, {DateTime? de, DateTime? ate}) {
  final dia = DateTime(data.year, data.month, data.day);
  if (de != null) {
    final inicio = DateTime(de.year, de.month, de.day);
    if (dia.isBefore(inicio)) return false;
  }
  if (ate != null) {
    final fim = DateTime(ate.year, ate.month, ate.day);
    if (dia.isAfter(fim)) return false;
  }
  return true;
}
