import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/movimentacao_estoque.dart';
import 'package:gymextreme_app/services/produto_service.dart';

import 'support/fake_produto_service.dart';

void main() {
  group('criarProduto', () {
    test('recusa estoque inicial negativo', () {
      final service = FakeProdutoService();

      expect(
        () => service.criarProduto(
          nome: 'Whey Protein',
          codigo: 'WP001',
          categoria: 'Suplementos',
          unidadeMedida: 'un',
          precoCusto: 50,
          precoVenda: 90,
          estoqueInicial: -5,
          estoqueMinimo: 5,
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        throwsA(isA<ProdutoServiceException>()),
      );
    });

    test('cadastra um produto novo, sempre ativo', () async {
      final service = FakeProdutoService();

      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(id, isNotEmpty);
      final produto = service.produtos.single;
      expect(produto.ativo, isTrue);
      expect(produto.nome, 'Whey Protein');
      expect(produto.estoqueAtual, 0);
      expect(produto.criadoPorNome, 'Ana');
    });

    test('aceita estoque inicial na criacao', () async {
      final service = FakeProdutoService();

      await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 20,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(service.produtos.single.estoqueAtual, 20);
    });
  });

  group('atualizarProduto', () {
    test('altera os dados de cadastro sem mexer no estoque', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 10,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await service.atualizarProduto(
        id,
        nome: 'Whey Protein Isolado',
        codigo: 'WP002',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 60,
        precoVenda: 110,
        estoqueMinimo: 8,
      );

      final produto = service.produtos.single;
      expect(produto.nome, 'Whey Protein Isolado');
      expect(produto.precoVenda, 110);
      expect(produto.estoqueMinimo, 8);
      expect(produto.estoqueAtual, 10, reason: 'atualizarProduto nunca mexe no estoque');
    });

    test('produto inexistente lanca excecao', () {
      final service = FakeProdutoService();

      expect(
        () => service.atualizarProduto(
          'inexistente',
          nome: 'X',
          codigo: 'X',
          categoria: 'X',
          unidadeMedida: 'un',
          precoCusto: 10,
          precoVenda: 20,
          estoqueMinimo: 1,
        ),
        throwsA(isA<ProdutoServiceException>()),
      );
    });
  });

  group('definirAtivo', () {
    test('desativa um produto sem apagar o documento (com historico preservado)', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 10,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );
      await service.registrarEntrada(id, quantidade: 5, staffUid: 's1', staffNome: 'Ana');

      await service.definirAtivo(id, false);

      expect(service.produtos, hasLength(1));
      expect(service.produtos.single.ativo, isFalse);
      expect(service.movimentacoesPorProduto[id], hasLength(1));
    });

    test('reativa um produto', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );
      await service.definirAtivo(id, false);

      await service.definirAtivo(id, true);

      expect(service.produtos.single.ativo, isTrue);
    });
  });

  group('registrarEntrada', () {
    test('soma a quantidade ao estoque e registra anterior/posterior', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 10,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      final movId = await service.registrarEntrada(
        id,
        quantidade: 15,
        motivo: 'Reposição mensal',
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(service.produtos.single.estoqueAtual, 25);
      final mov = service.movimentacoesPorProduto[id]!.single;
      expect(mov.id, movId);
      expect(mov.tipo, TipoMovimentacaoEstoque.entrada);
      expect(mov.quantidade, 15);
      expect(mov.estoqueAnterior, 10);
      expect(mov.estoquePosterior, 25);
      expect(mov.motivo, 'Reposição mensal');
    });
  });

  group('registrarSaida', () {
    test('subtrai a quantidade do estoque', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 10,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await service.registrarSaida(id, quantidade: 4, staffUid: 's1', staffNome: 'Ana');

      final produto = service.produtos.single;
      expect(produto.estoqueAtual, 6);
      expect(service.movimentacoesPorProduto[id]!.single.quantidade, -4);
    });

    test('recusa saida que deixaria o estoque negativo', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 3,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(
        () => service.registrarSaida(id, quantidade: 10, staffUid: 's1', staffNome: 'Ana'),
        throwsA(isA<ProdutoServiceException>()),
      );
      expect(service.produtos.single.estoqueAtual, 3, reason: 'estoque nao muda quando recusado');
      expect(service.movimentacoesPorProduto[id], isNull);
    });

    test('saida que zera o estoque exatamente e permitida', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 5,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await service.registrarSaida(id, quantidade: 5, staffUid: 's1', staffNome: 'Ana');

      expect(service.produtos.single.estoqueAtual, 0);
    });
  });

  group('registrarAjuste', () {
    test('ajuste positivo aumenta o estoque', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 10,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await service.registrarAjuste(
        id,
        quantidade: 3,
        motivo: 'Contagem de inventário',
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(service.produtos.single.estoqueAtual, 13);
      expect(
        service.movimentacoesPorProduto[id]!.single.tipo,
        TipoMovimentacaoEstoque.ajuste,
      );
    });

    test('ajuste negativo diminui o estoque', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 10,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await service.registrarAjuste(id, quantidade: -3, staffUid: 's1', staffNome: 'Ana');

      expect(service.produtos.single.estoqueAtual, 7);
    });

    test('ajuste que deixaria o estoque negativo tambem e recusado', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 5,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(
        () => service.registrarAjuste(id, quantidade: -10, staffUid: 's1', staffNome: 'Ana'),
        throwsA(isA<ProdutoServiceException>()),
      );
      expect(service.produtos.single.estoqueAtual, 5);
    });
  });

  group('historico de movimentacoes', () {
    test('acumula todas as movimentacoes em ordem, sem apagar nada', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 10,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await service.registrarEntrada(id, quantidade: 5, staffUid: 's1', staffNome: 'Ana');
      await service.registrarSaida(id, quantidade: 3, staffUid: 's1', staffNome: 'Ana');
      await service.registrarAjuste(id, quantidade: -1, staffUid: 's1', staffNome: 'Ana');

      final historico = service.movimentacoesPorProduto[id]!;
      expect(historico, hasLength(3));
      expect(historico[0].tipo, TipoMovimentacaoEstoque.entrada);
      expect(historico[1].tipo, TipoMovimentacaoEstoque.saida);
      expect(historico[2].tipo, TipoMovimentacaoEstoque.ajuste);
      expect(service.produtos.single.estoqueAtual, 11);
    });
  });

  group('Produto.estoqueMinimo / estoqueBaixo (integração com o service)', () {
    test('produto abaixo do minimo aparece marcado apos uma saida', () async {
      final service = FakeProdutoService();
      final id = await service.criarProduto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueInicial: 10,
        estoqueMinimo: 5,
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(service.produtos.single.estoqueBaixo, isFalse);

      await service.registrarSaida(id, quantidade: 6, staffUid: 's1', staffNome: 'Ana');

      expect(service.produtos.single.estoqueBaixo, isTrue);
    });
  });
}
