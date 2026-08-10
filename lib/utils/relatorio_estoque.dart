import '../models/movimentacao_estoque.dart';
import '../models/produto.dart';

/// Resumo de um conjunto de produtos — sempre calculado sobre uma lista
/// já carregada, nunca lê o Firestore.
class ResumoEstoque {
  const ResumoEstoque({
    required this.totalProdutos,
    required this.produtosAtivos,
    required this.produtosEstoqueBaixo,
    required this.valorTotalEstoqueCusto,
  });

  final int totalProdutos;
  final int produtosAtivos;

  /// Só considera produtos ativos — um produto inativo com estoque baixo
  /// não é uma pendência de reposição.
  final int produtosEstoqueBaixo;

  /// Soma de `estoqueAtual * precoCusto` de todos os produtos ativos —
  /// valor de custo do estoque parado, uma leitura gerencial comum.
  final double valorTotalEstoqueCusto;
}

ResumoEstoque calcularResumoEstoque(List<Produto> produtos) {
  final ativos = produtos.where((p) => p.ativo).toList();
  final estoqueBaixo = ativos.where((p) => p.estoqueBaixo).length;
  final valorTotal = ativos.fold<double>(
    0,
    (soma, p) => soma + (p.estoqueAtual * p.precoCusto),
  );

  return ResumoEstoque(
    totalProdutos: produtos.length,
    produtosAtivos: ativos.length,
    produtosEstoqueBaixo: estoqueBaixo,
    valorTotalEstoqueCusto: valorTotal,
  );
}

/// Totais de um conjunto de movimentações de estoque de UM produto (ver
/// `ProdutoService.watchMovimentacoes` — não existe consulta entre
/// produtos nesta fase).
class TotaisMovimentacaoEstoque {
  const TotaisMovimentacaoEstoque({
    required this.entradas,
    required this.saidas,
    required this.ajustes,
    required this.totalEntradas,
    required this.totalSaidas,
  });

  final int entradas;
  final int saidas;
  final int ajustes;

  /// Soma das quantidades de entrada (sempre positivas).
  final double totalEntradas;

  /// Soma das quantidades de saída, como magnitude positiva (a
  /// movimentação em si guarda `quantidade` negativa).
  final double totalSaidas;
}

TotaisMovimentacaoEstoque calcularTotaisMovimentacaoEstoque(
  List<MovimentacaoEstoque> movimentacoes,
) {
  var entradas = 0;
  var saidas = 0;
  var ajustes = 0;
  var totalEntradas = 0.0;
  var totalSaidas = 0.0;

  for (final mov in movimentacoes) {
    switch (mov.tipo) {
      case TipoMovimentacaoEstoque.entrada:
        entradas++;
        totalEntradas += mov.quantidade;
      case TipoMovimentacaoEstoque.saida:
        saidas++;
        totalSaidas += mov.quantidade.abs();
      case TipoMovimentacaoEstoque.ajuste:
        ajustes++;
    }
  }

  return TotaisMovimentacaoEstoque(
    entradas: entradas,
    saidas: saidas,
    ajustes: ajustes,
    totalEntradas: totalEntradas,
    totalSaidas: totalSaidas,
  );
}

/// Filtra movimentações de estoque cujo `criadoEm` cai dentro de
/// `[de, ate]`.
List<MovimentacaoEstoque> filtrarMovimentacoesEstoquePorPeriodo(
  List<MovimentacaoEstoque> movimentacoes, {
  DateTime? de,
  DateTime? ate,
}) {
  return movimentacoes.where((m) {
    if (m.criadoEm == null) return de == null && ate == null;
    return _dentroDoPeriodo(m.criadoEm!, de: de, ate: ate);
  }).toList();
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
