import 'package:cloud_firestore/cloud_firestore.dart';

/// Um produto do estoque interno da academia (coleção `produtos`, nível
/// de academia — mesmo padrão de `Plano`/`Caixa`, não pertence a nenhum
/// aluno). Cobre só cadastro e controle de estoque — não existe nenhum
/// fluxo de venda/PDV neste módulo (ver `ProdutoService` e
/// `MovimentacaoEstoque`).
///
/// Nunca é apagado: "excluir" (`ProdutoService.definirAtivo`) marca
/// [ativo] como `false` — o histórico de movimentações de estoque
/// continua existindo, mesmo raciocínio de `Plano.ativo`.
class Produto {
  const Produto({
    this.id,
    required this.nome,
    required this.codigo,
    required this.categoria,
    this.descricao,
    required this.unidadeMedida,
    required this.precoCusto,
    required this.precoVenda,
    this.estoqueAtual = 0,
    this.estoqueMinimo = 0,
    this.ativo = true,
    this.fornecedor,
    this.criadoEm,
    this.atualizadoEm,
    this.criadoPorUid,
    this.criadoPorNome,
  });

  final String? id;
  final String nome;

  /// Código/SKU — identificador curto de uso interno (etiqueta, busca
  /// rápida). Não é o id do documento no Firestore.
  final String codigo;
  final String categoria;
  final String? descricao;

  /// Ex.: "un", "kg", "cx" — texto livre, sem catálogo fixo por enquanto.
  final String unidadeMedida;

  final double precoCusto;
  final double precoVenda;

  /// Quantidade em estoque agora. Só muda através de uma
  /// `MovimentacaoEstoque` (`ProdutoService.registrarEntrada`/
  /// `registrarSaida`/`registrarAjuste`) — nunca editado diretamente pelo
  /// formulário de cadastro depois de criado, pra preservar a
  /// rastreabilidade completa de toda alteração.
  final double estoqueAtual;

  /// Limite pra alertar "estoque baixo" na lista — não bloqueia nenhuma
  /// operação, é só um indicador visual.
  final double estoqueMinimo;

  /// Produtos com histórico de movimentações nunca são apagados
  /// fisicamente — só desativados.
  final bool ativo;

  /// Texto livre, mesmo padrão de `ContaPagar.fornecedor` — não existe
  /// (ainda) uma entidade `Fornecedor` dedicada no app.
  final String? fornecedor;

  final DateTime? criadoEm;
  final DateTime? atualizadoEm;

  /// Auditoria: quem cadastrou o produto.
  final String? criadoPorUid;
  final String? criadoPorNome;

  /// `true` quando o estoque atual já está no limite mínimo ou abaixo
  /// dele — usado pelo filtro "estoque baixo" da lista e pelo destaque na
  /// tela de detalhes.
  bool get estoqueBaixo => estoqueAtual <= estoqueMinimo;

  factory Produto.fromFirestore(String id, Map<String, dynamic> data) {
    final criadoEm = data['criadoEm'];
    final atualizadoEm = data['atualizadoEm'];
    return Produto(
      id: id,
      nome: data['nome'] as String? ?? 'Produto',
      codigo: data['codigo'] as String? ?? '',
      categoria: data['categoria'] as String? ?? '',
      descricao: data['descricao'] as String?,
      unidadeMedida: data['unidadeMedida'] as String? ?? 'un',
      precoCusto: (data['precoCusto'] as num?)?.toDouble() ?? 0,
      precoVenda: (data['precoVenda'] as num?)?.toDouble() ?? 0,
      estoqueAtual: (data['estoqueAtual'] as num?)?.toDouble() ?? 0,
      estoqueMinimo: (data['estoqueMinimo'] as num?)?.toDouble() ?? 0,
      ativo: data['ativo'] as bool? ?? true,
      fornecedor: data['fornecedor'] as String?,
      criadoEm: criadoEm is Timestamp ? criadoEm.toDate() : null,
      atualizadoEm: atualizadoEm is Timestamp ? atualizadoEm.toDate() : null,
      criadoPorUid: data['criadoPorUid'] as String?,
      criadoPorNome: data['criadoPorNome'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'nome': nome,
      'codigo': codigo,
      'categoria': categoria,
      'descricao': descricao,
      'unidadeMedida': unidadeMedida,
      'precoCusto': precoCusto,
      'precoVenda': precoVenda,
      'estoqueAtual': estoqueAtual,
      'estoqueMinimo': estoqueMinimo,
      'ativo': ativo,
      'fornecedor': fornecedor,
      'criadoEm': criadoEm != null
          ? Timestamp.fromDate(criadoEm!)
          : FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
      if (criadoPorUid != null) 'criadoPorUid': criadoPorUid,
      if (criadoPorNome != null) 'criadoPorNome': criadoPorNome,
    };
  }

  Produto copyWith({
    String? nome,
    String? codigo,
    String? categoria,
    String? descricao,
    String? unidadeMedida,
    double? precoCusto,
    double? precoVenda,
    double? estoqueAtual,
    double? estoqueMinimo,
    bool? ativo,
    String? fornecedor,
  }) {
    return Produto(
      id: id,
      nome: nome ?? this.nome,
      codigo: codigo ?? this.codigo,
      categoria: categoria ?? this.categoria,
      descricao: descricao ?? this.descricao,
      unidadeMedida: unidadeMedida ?? this.unidadeMedida,
      precoCusto: precoCusto ?? this.precoCusto,
      precoVenda: precoVenda ?? this.precoVenda,
      estoqueAtual: estoqueAtual ?? this.estoqueAtual,
      estoqueMinimo: estoqueMinimo ?? this.estoqueMinimo,
      ativo: ativo ?? this.ativo,
      fornecedor: fornecedor ?? this.fornecedor,
      criadoEm: criadoEm,
      atualizadoEm: atualizadoEm,
      criadoPorUid: criadoPorUid,
      criadoPorNome: criadoPorNome,
    );
  }
}
