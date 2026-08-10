import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/produto.dart';

void main() {
  group('Produto.estoqueBaixo', () {
    test('estoque acima do minimo nao esta baixo', () {
      const produto = Produto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueAtual: 10,
        estoqueMinimo: 5,
      );
      expect(produto.estoqueBaixo, isFalse);
    });

    test('estoque igual ao minimo ja conta como baixo', () {
      const produto = Produto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueAtual: 5,
        estoqueMinimo: 5,
      );
      expect(produto.estoqueBaixo, isTrue);
    });

    test('estoque abaixo do minimo esta baixo', () {
      const produto = Produto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueAtual: 2,
        estoqueMinimo: 5,
      );
      expect(produto.estoqueBaixo, isTrue);
    });
  });

  group('Produto.fromFirestore / toFirestore', () {
    test('fromFirestore le todos os campos', () {
      final produto = Produto.fromFirestore('p1', {
        'nome': 'Whey Protein',
        'codigo': 'WP001',
        'categoria': 'Suplementos',
        'descricao': 'Whey concentrado 900g',
        'unidadeMedida': 'un',
        'precoCusto': 50.0,
        'precoVenda': 90.0,
        'estoqueAtual': 12.0,
        'estoqueMinimo': 5.0,
        'ativo': true,
        'fornecedor': 'Distribuidora X',
        'criadoPorUid': 'staff1',
        'criadoPorNome': 'Recepção Ana',
      });

      expect(produto.nome, 'Whey Protein');
      expect(produto.codigo, 'WP001');
      expect(produto.categoria, 'Suplementos');
      expect(produto.unidadeMedida, 'un');
      expect(produto.precoCusto, 50.0);
      expect(produto.precoVenda, 90.0);
      expect(produto.estoqueAtual, 12.0);
      expect(produto.estoqueMinimo, 5.0);
      expect(produto.ativo, isTrue);
      expect(produto.fornecedor, 'Distribuidora X');
      expect(produto.criadoPorNome, 'Recepção Ana');
    });

    test('fromFirestore usa padroes razoaveis pra documento incompleto', () {
      final produto = Produto.fromFirestore('p2', const {});
      expect(produto.nome, 'Produto');
      expect(produto.codigo, '');
      expect(produto.categoria, '');
      expect(produto.unidadeMedida, 'un');
      expect(produto.precoCusto, 0);
      expect(produto.precoVenda, 0);
      expect(produto.estoqueAtual, 0);
      expect(produto.estoqueMinimo, 0);
      expect(produto.ativo, isTrue);
      expect(produto.fornecedor, isNull);
    });

    test('toFirestore preserva os campos principais', () {
      const produto = Produto(
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueAtual: 12,
        estoqueMinimo: 5,
      );

      final dados = produto.toFirestore();
      expect(dados['nome'], 'Whey Protein');
      expect(dados['codigo'], 'WP001');
      expect(dados['categoria'], 'Suplementos');
      expect(dados['estoqueAtual'], 12);
      expect(dados['estoqueMinimo'], 5);
      expect(dados['ativo'], true);
    });
  });

  group('Produto.copyWith', () {
    test('desativar so troca o campo ativo', () {
      const produto = Produto(
        id: 'p1',
        nome: 'Whey Protein',
        codigo: 'WP001',
        categoria: 'Suplementos',
        unidadeMedida: 'un',
        precoCusto: 50,
        precoVenda: 90,
        estoqueAtual: 12,
        estoqueMinimo: 5,
      );

      final inativo = produto.copyWith(ativo: false);

      expect(inativo.ativo, isFalse);
      expect(inativo.nome, 'Whey Protein');
      expect(inativo.estoqueAtual, 12);
    });
  });

  test('Timestamp de criadoEm/atualizadoEm sao lidos corretamente', () {
    final produto = Produto.fromFirestore('p1', {
      'nome': 'Whey Protein',
      'criadoEm': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'atualizadoEm': Timestamp.fromDate(DateTime(2026, 2, 1)),
    });
    expect(produto.criadoEm, DateTime(2026, 1, 1));
    expect(produto.atualizadoEm, DateTime(2026, 2, 1));
  });
}
