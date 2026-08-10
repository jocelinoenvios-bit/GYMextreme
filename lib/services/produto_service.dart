import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/movimentacao_estoque.dart';
import '../models/produto.dart';

/// Catálogo de produtos e controle interno de estoque da academia
/// (coleção `produtos`, nível de academia — mesmo padrão de
/// `PlanoService`/`CaixaService`). Cada movimentação de estoque vive em
/// `produtos/{id}/movimentacoes`, mesma estrutura de
/// `caixas/{id}/movimentacoes`.
///
/// Deliberadamente não tem nenhuma noção de venda/PDV/pagamento — só
/// cadastro de produto e as 3 movimentações de estoque pedidas (entrada,
/// saída, ajuste).
class ProdutoService {
  ProdutoService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _produtos =>
      _firestore.collection('produtos');

  CollectionReference<Map<String, dynamic>> _movimentacoes(String produtoId) =>
      _produtos.doc(produtoId).collection('movimentacoes');

  /// Todos os produtos (ativos e inativos), por nome — a tela decide o
  /// que mostrar (busca, filtro de categoria, ativo/inativo, estoque
  /// baixo), mesmo padrão de `PlanoService.watchPlanos()`.
  Stream<List<Produto>> watchProdutos() {
    return _produtos.orderBy('nome').snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Produto.fromFirestore(doc.id, doc.data())).toList(),
    );
  }

  /// UM produto específico — usado pela tela de detalhes, que precisa
  /// acompanhar o estoque atual em tempo real conforme novas
  /// movimentações são registradas.
  Stream<Produto?> watchProduto(String id) {
    return _produtos.doc(id).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      return Produto.fromFirestore(doc.id, data);
    });
  }

  /// Movimentações de UM produto, mais recente primeiro. Sem
  /// `.orderBy()` no Firestore de propósito — mesmo motivo de
  /// `CaixaService.watchMovimentacoes()`: evita depender de índice
  /// composto; ordena no cliente.
  Stream<List<MovimentacaoEstoque>> watchMovimentacoes(String produtoId) {
    return _movimentacoes(produtoId).snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => MovimentacaoEstoque.fromFirestore(doc.id, doc.data()))
              .toList()
            ..sort((a, b) => (b.criadoEm ?? DateTime(0)).compareTo(a.criadoEm ?? DateTime(0))),
    );
  }

  /// Cadastra um produto novo — sempre nasce `ativo`. [estoqueInicial] só
  /// se aplica na criação (o produto pode já nascer com alguma
  /// quantidade em mãos); depois disso, `estoqueAtual` só muda através
  /// de [registrarEntrada]/[registrarSaida]/[registrarAjuste], nunca de
  /// [atualizarProduto].
  Future<String> criarProduto({
    required String nome,
    required String codigo,
    required String categoria,
    String? descricao,
    required String unidadeMedida,
    required double precoCusto,
    required double precoVenda,
    double estoqueInicial = 0,
    required double estoqueMinimo,
    String? fornecedor,
    required String staffUid,
    required String staffNome,
  }) async {
    if (estoqueInicial < 0) {
      throw ProdutoServiceException('O estoque inicial não pode ser negativo.');
    }
    final ref = await _produtos.add(
      Produto(
        nome: nome,
        codigo: codigo,
        categoria: categoria,
        descricao: descricao,
        unidadeMedida: unidadeMedida,
        precoCusto: precoCusto,
        precoVenda: precoVenda,
        estoqueAtual: estoqueInicial,
        estoqueMinimo: estoqueMinimo,
        fornecedor: fornecedor,
        criadoPorUid: staffUid,
        criadoPorNome: staffNome,
      ).toFirestore(),
    );
    return ref.id;
  }

  /// Edita os dados de cadastro do produto. Nunca mexe em
  /// `estoqueAtual`/`ativo` — isso é sempre [registrarEntrada]/
  /// [registrarSaida]/[registrarAjuste]/[definirAtivo], nunca esta
  /// função.
  Future<void> atualizarProduto(
    String produtoId, {
    required String nome,
    required String codigo,
    required String categoria,
    String? descricao,
    required String unidadeMedida,
    required double precoCusto,
    required double precoVenda,
    required double estoqueMinimo,
    String? fornecedor,
  }) {
    return _produtos.doc(produtoId).set({
      'nome': nome,
      'codigo': codigo,
      'categoria': categoria,
      'descricao': descricao,
      'unidadeMedida': unidadeMedida,
      'precoCusto': precoCusto,
      'precoVenda': precoVenda,
      'estoqueMinimo': estoqueMinimo,
      'fornecedor': fornecedor,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Ativa/desativa um produto sem apagar o documento — mesmo padrão de
  /// `PlanoService.excluirPlano`: produtos com histórico de
  /// movimentações nunca são apagados fisicamente, só somem da lista de
  /// produtos disponíveis (a tela decide se mostra inativos ou não).
  Future<void> definirAtivo(String produtoId, bool ativo) {
    return _produtos.doc(produtoId).set({
      'ativo': ativo,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Entrada de estoque — sempre soma [quantidade] (magnitude positiva
  /// digitada pelo usuário) ao estoque atual.
  Future<String> registrarEntrada(
    String produtoId, {
    required double quantidade,
    String? motivo,
    required String staffUid,
    required String staffNome,
  }) {
    return _registrarMovimentacao(
      produtoId,
      tipo: TipoMovimentacaoEstoque.entrada,
      delta: quantidade.abs(),
      motivo: motivo,
      staffUid: staffUid,
      staffNome: staffNome,
    );
  }

  /// Saída de estoque — sempre subtrai [quantidade] (magnitude positiva
  /// digitada pelo usuário) do estoque atual. Lança
  /// [ProdutoServiceException] se a saída deixaria o estoque negativo —
  /// "não permitir estoque negativo" vale pra toda movimentação, não só
  /// pra saída.
  Future<String> registrarSaida(
    String produtoId, {
    required double quantidade,
    String? motivo,
    required String staffUid,
    required String staffNome,
  }) {
    return _registrarMovimentacao(
      produtoId,
      tipo: TipoMovimentacaoEstoque.saida,
      delta: -quantidade.abs(),
      motivo: motivo,
      staffUid: staffUid,
      staffNome: staffNome,
    );
  }

  /// Ajuste autorizado — [quantidade] já vem assinada (pode corrigir pra
  /// cima ou pra baixo), já que uma correção de inventário pode ir pros
  /// dois lados. Mesma regra de "nunca negativo" das demais.
  Future<String> registrarAjuste(
    String produtoId, {
    required double quantidade,
    String? motivo,
    required String staffUid,
    required String staffNome,
  }) {
    return _registrarMovimentacao(
      produtoId,
      tipo: TipoMovimentacaoEstoque.ajuste,
      delta: quantidade,
      motivo: motivo,
      staffUid: staffUid,
      staffNome: staffNome,
    );
  }

  /// Núcleo comum das 3 movimentações: lê o estoque atual, calcula o
  /// novo valor, recusa se ficaria negativo, e grava a atualização do
  /// produto + o registro da movimentação (com o retrato
  /// anterior/posterior) na mesma transação — garante que as duas
  /// escritas nunca ficam dessincronizadas mesmo sob concorrência.
  Future<String> _registrarMovimentacao(
    String produtoId, {
    required TipoMovimentacaoEstoque tipo,
    required double delta,
    String? motivo,
    required String staffUid,
    required String staffNome,
  }) {
    final produtoRef = _produtos.doc(produtoId);
    final movRef = _movimentacoes(produtoId).doc();

    return _firestore.runTransaction<String>((transaction) async {
      final produtoSnap = await transaction.get(produtoRef);
      if (!produtoSnap.exists) {
        throw ProdutoServiceException('Produto não encontrado.');
      }

      final estoqueAnterior = (produtoSnap.data()?['estoqueAtual'] as num?)?.toDouble() ?? 0;
      final estoquePosterior = estoqueAnterior + delta;
      if (estoquePosterior < 0) {
        throw ProdutoServiceException('Estoque insuficiente para esta movimentação.');
      }

      transaction.update(produtoRef, {
        'estoqueAtual': estoquePosterior,
        'atualizadoEm': FieldValue.serverTimestamp(),
      });

      transaction.set(
        movRef,
        MovimentacaoEstoque(
          tipo: tipo,
          quantidade: delta,
          estoqueAnterior: estoqueAnterior,
          estoquePosterior: estoquePosterior,
          motivo: motivo,
          staffUid: staffUid,
          staffNome: staffNome,
        ).toFirestore(),
      );

      return movRef.id;
    });
  }
}

/// Erro de operação de produto/estoque com mensagem pronta pra exibir ao
/// usuário.
class ProdutoServiceException implements Exception {
  ProdutoServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
