import 'package:cloud_firestore/cloud_firestore.dart';

/// Categoria de uma [MovimentacaoEstoque].
enum TipoMovimentacaoEstoque {
  entrada,
  saida,
  ajuste;

  String get label => switch (this) {
    TipoMovimentacaoEstoque.entrada => 'Entrada',
    TipoMovimentacaoEstoque.saida => 'Saída',
    TipoMovimentacaoEstoque.ajuste => 'Ajuste',
  };

  static TipoMovimentacaoEstoque fromFirestoreValue(String? value) {
    for (final tipo in TipoMovimentacaoEstoque.values) {
      if (tipo.name == value) return tipo;
    }
    return TipoMovimentacaoEstoque.ajuste;
  }
}

/// Uma movimentação de estoque de UM produto (coleção
/// `produtos/{produtoId}/movimentacoes`) — histórico permanente, nunca
/// editado nem apagado (ver `ProdutoService.registrarEntrada`/
/// `registrarSaida`/`registrarAjuste`, todas dentro de uma transação que
/// também atualiza `Produto.estoqueAtual`).
///
/// [quantidade] é sempre a contribuição JÁ ASSINADA pro estoque: positiva
/// pra [TipoMovimentacaoEstoque.entrada], negativa pra
/// [TipoMovimentacaoEstoque.saida]; pra [TipoMovimentacaoEstoque.ajuste] o
/// valor pode ir pros dois lados (`ProdutoService.registrarAjuste`
/// normaliza o sinal antes de gravar) — mesmo raciocínio de
/// `CaixaMovimentacao.valor`. [estoqueAnterior]/[estoquePosterior] são um
/// retrato do estoque no instante exato desta movimentação, pedido
/// explicitamente pra rastreabilidade completa.
class MovimentacaoEstoque {
  const MovimentacaoEstoque({
    this.id,
    required this.tipo,
    required this.quantidade,
    required this.estoqueAnterior,
    required this.estoquePosterior,
    this.motivo,
    required this.staffUid,
    required this.staffNome,
    this.criadoEm,
  });

  final String? id;
  final TipoMovimentacaoEstoque tipo;
  final double quantidade;
  final double estoqueAnterior;
  final double estoquePosterior;
  final String? motivo;
  final String staffUid;
  final String staffNome;
  final DateTime? criadoEm;

  factory MovimentacaoEstoque.fromFirestore(String id, Map<String, dynamic> data) {
    final criadoEm = data['criadoEm'];
    return MovimentacaoEstoque(
      id: id,
      tipo: TipoMovimentacaoEstoque.fromFirestoreValue(data['tipo'] as String?),
      quantidade: (data['quantidade'] as num?)?.toDouble() ?? 0,
      estoqueAnterior: (data['estoqueAnterior'] as num?)?.toDouble() ?? 0,
      estoquePosterior: (data['estoquePosterior'] as num?)?.toDouble() ?? 0,
      motivo: data['motivo'] as String?,
      staffUid: data['staffUid'] as String? ?? '',
      staffNome: data['staffNome'] as String? ?? '',
      criadoEm: criadoEm is Timestamp ? criadoEm.toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tipo': tipo.name,
      'quantidade': quantidade,
      'estoqueAnterior': estoqueAnterior,
      'estoquePosterior': estoquePosterior,
      'motivo': motivo,
      'staffUid': staffUid,
      'staffNome': staffNome,
      'criadoEm': criadoEm != null
          ? Timestamp.fromDate(criadoEm!)
          : FieldValue.serverTimestamp(),
    };
  }
}
