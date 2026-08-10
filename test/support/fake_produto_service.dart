import 'package:gymextreme_app/models/movimentacao_estoque.dart';
import 'package:gymextreme_app/models/produto.dart';
import 'package:gymextreme_app/services/produto_service.dart';

/// Dublê de teste do [ProdutoService] — mesmo padrão de
/// [FakeCaixaService]/[FakeContaPagarService]: implementa a mesma
/// interface pública sem tocar o Firestore de verdade.
class FakeProdutoService implements ProdutoService {
  FakeProdutoService({List<Produto> produtos = const []}) : produtos = List.of(produtos);

  List<Produto> produtos;
  final Map<String, List<MovimentacaoEstoque>> movimentacoesPorProduto = {};

  String? ultimoProdutoCriadoId;
  String? ultimoProdutoAtualizadoId;
  ({String produtoId, bool ativo})? ultimaDefinicaoAtivo;
  MovimentacaoEstoque? ultimaMovimentacaoRegistrada;

  int _proximoId = 1;

  Produto? _acharPorId(String id) {
    for (final produto in produtos) {
      if (produto.id == id) return produto;
    }
    return null;
  }

  void _substituir(Produto atualizado) {
    produtos = [
      for (final produto in produtos) if (produto.id == atualizado.id) atualizado else produto,
    ];
  }

  @override
  Stream<List<Produto>> watchProdutos() => Stream.value(produtos);

  @override
  Stream<Produto?> watchProduto(String id) => Stream.value(_acharPorId(id));

  @override
  Stream<List<MovimentacaoEstoque>> watchMovimentacoes(String produtoId) =>
      Stream.value(movimentacoesPorProduto[produtoId] ?? const []);

  @override
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
    final id = 'produto-${_proximoId++}';
    final produto = Produto(
      id: id,
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
    );
    produtos = [...produtos, produto];
    ultimoProdutoCriadoId = id;
    return id;
  }

  @override
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
  }) async {
    final atual = _acharPorId(produtoId);
    if (atual == null) {
      throw ProdutoServiceException('Produto não encontrado.');
    }
    _substituir(
      atual.copyWith(
        nome: nome,
        codigo: codigo,
        categoria: categoria,
        descricao: descricao,
        unidadeMedida: unidadeMedida,
        precoCusto: precoCusto,
        precoVenda: precoVenda,
        estoqueMinimo: estoqueMinimo,
        fornecedor: fornecedor,
      ),
    );
    ultimoProdutoAtualizadoId = produtoId;
  }

  @override
  Future<void> definirAtivo(String produtoId, bool ativo) async {
    final atual = _acharPorId(produtoId);
    if (atual == null) {
      throw ProdutoServiceException('Produto não encontrado.');
    }
    _substituir(atual.copyWith(ativo: ativo));
    ultimaDefinicaoAtivo = (produtoId: produtoId, ativo: ativo);
  }

  Future<String> _registrarMovimentacao(
    String produtoId, {
    required TipoMovimentacaoEstoque tipo,
    required double delta,
    String? motivo,
    required String staffUid,
    required String staffNome,
  }) async {
    final atual = _acharPorId(produtoId);
    if (atual == null) {
      throw ProdutoServiceException('Produto não encontrado.');
    }
    final estoquePosterior = atual.estoqueAtual + delta;
    if (estoquePosterior < 0) {
      throw ProdutoServiceException('Estoque insuficiente para esta movimentação.');
    }

    _substituir(atual.copyWith(estoqueAtual: estoquePosterior));

    final existentes = movimentacoesPorProduto[produtoId] ?? const [];
    final mov = MovimentacaoEstoque(
      id: 'mov-${existentes.length + 1}',
      tipo: tipo,
      quantidade: delta,
      estoqueAnterior: atual.estoqueAtual,
      estoquePosterior: estoquePosterior,
      motivo: motivo,
      staffUid: staffUid,
      staffNome: staffNome,
      criadoEm: DateTime.now(),
    );
    movimentacoesPorProduto[produtoId] = [...existentes, mov];
    ultimaMovimentacaoRegistrada = mov;
    return mov.id!;
  }

  @override
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

  @override
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

  @override
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
}
