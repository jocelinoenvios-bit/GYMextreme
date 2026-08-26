import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/caixa_movimentacao.dart';
import 'package:gymextreme_app/models/conta_pagar.dart';
import 'package:gymextreme_app/models/conta_receber.dart';
import 'package:gymextreme_app/utils/relatorio_financeiro.dart';

final _hoje = DateTime(2026, 8, 10);

void main() {
  group('calcularTotaisContasReceber', () {
    test('separa em aberto, vencido e pago corretamente', () {
      final totais = calcularTotaisContasReceber([
        ContaReceber(
          alunoId: 'a1',
          descricao: 'Pendente',
          valorOriginal: 100,
          vencimento: DateTime(2026, 12, 1),
        ),
        ContaReceber(
          alunoId: 'a1',
          descricao: 'Vencida',
          valorOriginal: 50,
          vencimento: DateTime(2020, 1, 1),
        ),
        ContaReceber(
          alunoId: 'a1',
          descricao: 'Paga',
          valorOriginal: 200,
          valorPago: 200,
          vencimento: DateTime(2026, 1, 1),
          status: StatusContaReceber.pago,
        ),
        ContaReceber(
          alunoId: 'a1',
          descricao: 'Cancelada',
          valorOriginal: 300,
          vencimento: DateTime(2026, 1, 1),
          status: StatusContaReceber.cancelado,
        ),
      ], hoje: _hoje);

      expect(totais.quantidade, 4);
      expect(totais.totalEmAberto, 100);
      expect(totais.totalVencido, 50);
      expect(totais.totalPago, 200);
    });

    test('lista vazia da totais zerados', () {
      final totais = calcularTotaisContasReceber(const [], hoje: _hoje);
      expect(totais.quantidade, 0);
      expect(totais.totalEmAberto, 0);
      expect(totais.totalVencido, 0);
      expect(totais.totalPago, 0);
    });
  });

  group('calcularTotaisContasPagar', () {
    test('separa em aberto, vencido e pago corretamente', () {
      final totais = calcularTotaisContasPagar([
        ContaPagar(
          fornecedor: 'F1',
          descricao: 'Aluguel',
          categoria: 'Aluguel',
          valorOriginal: 1000,
          vencimento: DateTime(2026, 12, 1),
        ),
        ContaPagar(
          fornecedor: 'F2',
          descricao: 'Luz vencida',
          categoria: 'Utilidades',
          valorOriginal: 300,
          vencimento: DateTime(2020, 1, 1),
        ),
        ContaPagar(
          fornecedor: 'F3',
          descricao: 'Agua paga',
          categoria: 'Utilidades',
          valorOriginal: 150,
          valorPago: 150,
          vencimento: DateTime(2026, 1, 1),
          status: StatusContaPagar.pago,
        ),
      ], hoje: _hoje);

      expect(totais.totalEmAberto, 1000);
      expect(totais.totalVencido, 300);
      expect(totais.totalPago, 150);
    });
  });

  group('filtrarContasReceberPorPeriodo', () {
    final contas = [
      ContaReceber(
        alunoId: 'a1',
        descricao: 'Julho',
        valorOriginal: 100,
        vencimento: DateTime(2026, 7, 15),
      ),
      ContaReceber(
        alunoId: 'a1',
        descricao: 'Agosto',
        valorOriginal: 100,
        vencimento: DateTime(2026, 8, 15),
      ),
      ContaReceber(
        alunoId: 'a1',
        descricao: 'Setembro',
        valorOriginal: 100,
        vencimento: DateTime(2026, 9, 15),
      ),
    ];

    test('sem periodo informado, retorna tudo', () {
      expect(filtrarContasReceberPorPeriodo(contas), hasLength(3));
    });

    test('filtra pelo intervalo de vencimento (extremos inclusos)', () {
      final filtradas = filtrarContasReceberPorPeriodo(
        contas,
        de: DateTime(2026, 8, 1),
        ate: DateTime(2026, 8, 31),
      );
      expect(filtradas, hasLength(1));
      expect(filtradas.single.descricao, 'Agosto');
    });

    test('so com limite inferior, pega tudo dali pra frente', () {
      final filtradas = filtrarContasReceberPorPeriodo(contas, de: DateTime(2026, 8, 1));
      expect(filtradas, hasLength(2));
    });
  });

  group('filtrarContasPagarPorPeriodo', () {
    test('filtra pelo intervalo de vencimento', () {
      final contas = [
        ContaPagar(
          fornecedor: 'F1',
          descricao: 'Julho',
          categoria: 'Cat',
          valorOriginal: 100,
          vencimento: DateTime(2026, 7, 15),
        ),
        ContaPagar(
          fornecedor: 'F1',
          descricao: 'Agosto',
          categoria: 'Cat',
          valorOriginal: 100,
          vencimento: DateTime(2026, 8, 15),
        ),
      ];

      final filtradas = filtrarContasPagarPorPeriodo(
        contas,
        de: DateTime(2026, 8, 1),
        ate: DateTime(2026, 8, 31),
      );
      expect(filtradas, hasLength(1));
      expect(filtradas.single.descricao, 'Agosto');
    });
  });

  group('filtrarMovimentacoesCaixaPorPeriodo / somarMovimentacoesCaixa', () {
    test('filtra pelo criadoEm e soma os valores assinados', () {
      final movimentacoes = [
        CaixaMovimentacao(
          tipo: TipoMovimentacaoCaixa.suprimento,
          valor: 50,
          staffUid: 's1',
          staffNome: 'Ana',
          criadoEm: DateTime(2026, 8, 5),
        ),
        CaixaMovimentacao(
          tipo: TipoMovimentacaoCaixa.retirada,
          valor: -20,
          staffUid: 's1',
          staffNome: 'Ana',
          criadoEm: DateTime(2026, 8, 20),
        ),
        CaixaMovimentacao(
          tipo: TipoMovimentacaoCaixa.suprimento,
          valor: 100,
          staffUid: 's1',
          staffNome: 'Ana',
          criadoEm: DateTime(2026, 9, 1),
        ),
      ];

      final doMesDeAgosto = filtrarMovimentacoesCaixaPorPeriodo(
        movimentacoes,
        de: DateTime(2026, 8, 1),
        ate: DateTime(2026, 8, 31),
      );

      expect(doMesDeAgosto, hasLength(2));
      expect(somarMovimentacoesCaixa(doMesDeAgosto), 30);
      expect(somarMovimentacoesCaixa(movimentacoes), 130);
    });

    test('soma de lista vazia e zero', () {
      expect(somarMovimentacoesCaixa(const []), 0);
    });
  });
}
