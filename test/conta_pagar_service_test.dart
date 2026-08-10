import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/conta_pagar.dart';
import 'package:gymextreme_app/services/conta_pagar_service.dart';

import 'support/fake_conta_pagar_service.dart';

void main() {
  group('criarContaPagar', () {
    test('cria uma despesa nova, sempre pendente', () async {
      final service = FakeContaPagarService();

      final id = await service.criarContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(id, isNotEmpty);
      final conta = service.contas.single;
      expect(conta.status, StatusContaPagar.pendente);
      expect(conta.fornecedor, 'Fornecedor X');
      expect(conta.criadoPorNome, 'Ana');
    });
  });

  group('atualizarContaPagar', () {
    test('altera os dados basicos sem mexer no status', () async {
      final service = FakeContaPagarService();
      final id = await service.criarContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await service.atualizarContaPagar(
        id,
        fornecedor: 'Fornecedor Y',
        descricao: 'Aluguel (reajustado)',
        categoria: 'Aluguel',
        valorOriginal: 1200,
        desconto: 0,
        jurosMulta: 0,
        vencimento: DateTime(2026, 9, 10),
      );

      final conta = service.contas.single;
      expect(conta.fornecedor, 'Fornecedor Y');
      expect(conta.valorOriginal, 1200);
      expect(conta.vencimento, DateTime(2026, 9, 10));
      expect(conta.status, StatusContaPagar.pendente);
    });

    test('conta inexistente lanca excecao', () {
      final service = FakeContaPagarService();

      expect(
        () => service.atualizarContaPagar(
          'inexistente',
          fornecedor: 'X',
          descricao: 'X',
          categoria: 'X',
          valorOriginal: 100,
          desconto: 0,
          jurosMulta: 0,
          vencimento: DateTime(2026, 9, 5),
        ),
        throwsA(isA<ContaPagarServiceException>()),
      );
    });
  });

  group('excluirContaPagar', () {
    test('marca como cancelado sem apagar o documento', () async {
      final service = FakeContaPagarService();
      final id = await service.criarContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await service.excluirContaPagar(id);

      expect(service.contas, hasLength(1));
      expect(service.contas.single.status, StatusContaPagar.cancelado);
    });
  });

  group('registrarPagamentoSemCaixa', () {
    test('marca como pago e registra valores/responsavel', () async {
      final service = FakeContaPagarService();
      final id = await service.criarContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
        staffUid: 's1',
        staffNome: 'Ana',
      );

      await service.registrarPagamentoSemCaixa(
        id,
        valorPago: 1000,
        desconto: 0,
        jurosMulta: 0,
        dataPagamento: DateTime(2026, 9, 4),
        formaPagamento: 'PIX',
        staffUid: 's2',
        staffNome: 'Bia',
      );

      final conta = service.contas.single;
      expect(conta.status, StatusContaPagar.pago);
      expect(conta.valorPago, 1000);
      expect(conta.pagoPorNome, 'Bia');
    });

    test('recusa pagar de novo uma conta ja paga (pagamento duplicado)', () async {
      final service = FakeContaPagarService();
      final id = await service.criarContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
        staffUid: 's1',
        staffNome: 'Ana',
      );
      await service.registrarPagamentoSemCaixa(
        id,
        valorPago: 1000,
        desconto: 0,
        jurosMulta: 0,
        dataPagamento: DateTime(2026, 9, 4),
        staffUid: 's1',
        staffNome: 'Ana',
      );

      expect(
        () => service.registrarPagamentoSemCaixa(
          id,
          valorPago: 1000,
          desconto: 0,
          jurosMulta: 0,
          dataPagamento: DateTime(2026, 9, 4),
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        throwsA(isA<ContaPagarServiceException>()),
      );
    });

    test('conta inexistente lanca excecao', () {
      final service = FakeContaPagarService();

      expect(
        () => service.registrarPagamentoSemCaixa(
          'inexistente',
          valorPago: 100,
          desconto: 0,
          jurosMulta: 0,
          dataPagamento: DateTime(2026, 9, 4),
          staffUid: 's1',
          staffNome: 'Ana',
        ),
        throwsA(isA<ContaPagarServiceException>()),
      );
    });
  });
}
