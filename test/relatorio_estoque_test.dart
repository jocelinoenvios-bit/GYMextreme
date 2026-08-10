import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/movimentacao_estoque.dart';
import 'package:gymextreme_app/models/produto.dart';
import 'package:gymextreme_app/utils/relatorio_estoque.dart';

Produto _produto({
  required String id,
  double estoqueAtual = 10,
  double estoqueMinimo = 5,
  double precoCusto = 10,
  bool ativo = true,
}) {
  return Produto(
    id: id,
    nome: 'Produto $id',
    codigo: id,
    categoria: 'Cat',
    unidadeMedida: 'un',
    precoCusto: precoCusto,
    precoVenda: precoCusto * 2,
    estoqueAtual: estoqueAtual,
    estoqueMinimo: estoqueMinimo,
    ativo: ativo,
  );
}

void main() {
  group('calcularResumoEstoque', () {
    test('lista vazia da resumo zerado', () {
      final resumo = calcularResumoEstoque(const []);
      expect(resumo.totalProdutos, 0);
      expect(resumo.produtosAtivos, 0);
      expect(resumo.produtosEstoqueBaixo, 0);
      expect(resumo.valorTotalEstoqueCusto, 0);
    });

    test('conta so produtos ativos com estoque baixo', () {
      final resumo = calcularResumoEstoque([
        _produto(id: 'p1', estoqueAtual: 2, estoqueMinimo: 5),
        _produto(id: 'p2', estoqueAtual: 20, estoqueMinimo: 5),
        _produto(id: 'p3', estoqueAtual: 1, estoqueMinimo: 5, ativo: false),
      ]);

      expect(resumo.totalProdutos, 3);
      expect(resumo.produtosAtivos, 2);
      expect(resumo.produtosEstoqueBaixo, 1);
    });

    test('soma o valor de custo do estoque, so de produtos ativos', () {
      final resumo = calcularResumoEstoque([
        _produto(id: 'p1', estoqueAtual: 10, precoCusto: 5), // 50
        _produto(id: 'p2', estoqueAtual: 2, precoCusto: 20), // 40
        _produto(id: 'p3', estoqueAtual: 100, precoCusto: 99, ativo: false), // ignorado
      ]);

      expect(resumo.valorTotalEstoqueCusto, 90);
    });
  });

  group('calcularTotaisMovimentacaoEstoque', () {
    test('lista vazia da totais zerados', () {
      final totais = calcularTotaisMovimentacaoEstoque(const []);
      expect(totais.entradas, 0);
      expect(totais.saidas, 0);
      expect(totais.ajustes, 0);
      expect(totais.totalEntradas, 0);
      expect(totais.totalSaidas, 0);
    });

    test('separa entrada/saida/ajuste e soma as quantidades', () {
      final totais = calcularTotaisMovimentacaoEstoque(const [
        MovimentacaoEstoque(
          tipo: TipoMovimentacaoEstoque.entrada,
          quantidade: 10,
          estoqueAnterior: 0,
          estoquePosterior: 10,
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        MovimentacaoEstoque(
          tipo: TipoMovimentacaoEstoque.entrada,
          quantidade: 5,
          estoqueAnterior: 10,
          estoquePosterior: 15,
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        MovimentacaoEstoque(
          tipo: TipoMovimentacaoEstoque.saida,
          quantidade: -3,
          estoqueAnterior: 15,
          estoquePosterior: 12,
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        MovimentacaoEstoque(
          tipo: TipoMovimentacaoEstoque.ajuste,
          quantidade: -1,
          estoqueAnterior: 12,
          estoquePosterior: 11,
          staffUid: 's1',
          staffNome: 'Ana',
        ),
      ]);

      expect(totais.entradas, 2);
      expect(totais.saidas, 1);
      expect(totais.ajustes, 1);
      expect(totais.totalEntradas, 15);
      expect(totais.totalSaidas, 3);
    });
  });

  group('filtrarMovimentacoesEstoquePorPeriodo', () {
    test('filtra pelo criadoEm', () {
      final movimentacoes = [
        MovimentacaoEstoque(
          tipo: TipoMovimentacaoEstoque.entrada,
          quantidade: 10,
          estoqueAnterior: 0,
          estoquePosterior: 10,
          staffUid: 's1',
          staffNome: 'Ana',
          criadoEm: DateTime(2026, 7, 1),
        ),
        MovimentacaoEstoque(
          tipo: TipoMovimentacaoEstoque.saida,
          quantidade: -2,
          estoqueAnterior: 10,
          estoquePosterior: 8,
          staffUid: 's1',
          staffNome: 'Ana',
          criadoEm: DateTime(2026, 8, 15),
        ),
      ];

      final filtradas = filtrarMovimentacoesEstoquePorPeriodo(
        movimentacoes,
        de: DateTime(2026, 8, 1),
        ate: DateTime(2026, 8, 31),
      );

      expect(filtradas, hasLength(1));
      expect(filtradas.single.tipo, TipoMovimentacaoEstoque.saida);
    });
  });
}
