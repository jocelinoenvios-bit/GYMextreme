import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/conta_pagar.dart';

void main() {
  group('StatusContaPagar', () {
    test('fromFirestoreValue reconhece os 4 status', () {
      expect(StatusContaPagar.fromFirestoreValue('pendente'), StatusContaPagar.pendente);
      expect(StatusContaPagar.fromFirestoreValue('pago'), StatusContaPagar.pago);
      expect(StatusContaPagar.fromFirestoreValue('vencido'), StatusContaPagar.vencido);
      expect(StatusContaPagar.fromFirestoreValue('cancelado'), StatusContaPagar.cancelado);
    });

    test('fromFirestoreValue com valor desconhecido/nulo cai em pendente', () {
      expect(StatusContaPagar.fromFirestoreValue(null), StatusContaPagar.pendente);
      expect(StatusContaPagar.fromFirestoreValue('lixo'), StatusContaPagar.pendente);
    });
  });

  group('ContaPagar.valorFinal', () {
    test('sem desconto nem juros, e igual ao valor original', () {
      final conta = ContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
      );
      expect(conta.valorFinal, 1000);
    });

    test('desconto reduz o valor final', () {
      final conta = ContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        desconto: 100,
        vencimento: DateTime(2026, 9, 5),
      );
      expect(conta.valorFinal, 900);
    });

    test('juros/multa aumentam o valor final', () {
      final conta = ContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        jurosMulta: 50,
        vencimento: DateTime(2026, 9, 5),
      );
      expect(conta.valorFinal, 1050);
    });

    test('desconto maior que o valor original nunca fica negativo', () {
      final conta = ContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 50,
        desconto: 200,
        vencimento: DateTime(2026, 9, 5),
      );
      expect(conta.valorFinal, 0);
    });
  });

  group('ContaPagar.saldoAPagar', () {
    test('sem nenhum pagamento, o saldo e o valor final inteiro', () {
      final conta = ContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
      );
      expect(conta.saldoAPagar, 1000);
    });

    test('pagamento parcial deixa saldo positivo', () {
      final conta = ContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        valorPago: 600,
        vencimento: DateTime(2026, 9, 5),
      );
      expect(conta.saldoAPagar, 400);
    });

    test('pagamento maior que o valor final deixa saldo negativo (pago a mais)', () {
      final conta = ContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        valorPago: 1200,
        vencimento: DateTime(2026, 9, 5),
      );
      expect(conta.saldoAPagar, -200);
    });
  });

  group('ContaPagar.fromFirestore / toFirestore', () {
    test('fromFirestore le todos os campos', () {
      final conta = ContaPagar.fromFirestore('conta1', {
        'fornecedor': 'Energia Elétrica S.A.',
        'descricao': 'Conta de luz agosto',
        'categoria': 'Utilidades',
        'valorOriginal': 450.5,
        'valorPago': 450.5,
        'desconto': 0,
        'jurosMulta': 0,
        'vencimento': Timestamp.fromDate(DateTime(2026, 8, 10)),
        'dataPagamento': Timestamp.fromDate(DateTime(2026, 8, 5)),
        'status': 'pago',
        'formaPagamento': 'PIX',
        'observacao': 'Pago adiantado',
        'criadoPorUid': 'staff1',
        'criadoPorNome': 'Recepção Ana',
        'pagoPorUid': 'staff1',
        'pagoPorNome': 'Recepção Ana',
      });

      expect(conta.fornecedor, 'Energia Elétrica S.A.');
      expect(conta.descricao, 'Conta de luz agosto');
      expect(conta.categoria, 'Utilidades');
      expect(conta.valorOriginal, 450.5);
      expect(conta.valorPago, 450.5);
      expect(conta.vencimento, DateTime(2026, 8, 10));
      expect(conta.dataPagamento, DateTime(2026, 8, 5));
      expect(conta.status, StatusContaPagar.pago);
      expect(conta.formaPagamento, 'PIX');
      expect(conta.pagoPorNome, 'Recepção Ana');
    });

    test('fromFirestore usa padroes razoaveis pra documento incompleto', () {
      final conta = ContaPagar.fromFirestore('conta2', const {});
      expect(conta.descricao, 'Despesa');
      expect(conta.fornecedor, '');
      expect(conta.categoria, '');
      expect(conta.valorOriginal, 0);
      expect(conta.desconto, 0);
      expect(conta.jurosMulta, 0);
      expect(conta.status, StatusContaPagar.pendente);
      expect(conta.valorPago, isNull);
    });

    test('toFirestore preserva os campos principais', () {
      final conta = ContaPagar(
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
      );

      final dados = conta.toFirestore();
      expect(dados['fornecedor'], 'Fornecedor X');
      expect(dados['descricao'], 'Aluguel');
      expect(dados['categoria'], 'Aluguel');
      expect(dados['valorOriginal'], 1000);
      expect(dados['status'], 'pendente');
      expect(dados['valorPago'], isNull);
    });
  });

  group('ContaPagar.copyWith', () {
    test('registrar pagamento so troca os campos do pagamento', () {
      final conta = ContaPagar(
        id: 'conta1',
        fornecedor: 'Fornecedor X',
        descricao: 'Aluguel',
        categoria: 'Aluguel',
        valorOriginal: 1000,
        vencimento: DateTime(2026, 9, 5),
      );

      final paga = conta.copyWith(
        status: StatusContaPagar.pago,
        valorPago: 1000,
        dataPagamento: DateTime(2026, 8, 28),
        formaPagamento: 'PIX',
        pagoPorUid: 'staff1',
        pagoPorNome: 'Recepção Ana',
      );

      expect(paga.status, StatusContaPagar.pago);
      expect(paga.valorPago, 1000);
      expect(paga.descricao, 'Aluguel');
      expect(paga.valorOriginal, 1000);
      expect(paga.pagoPorNome, 'Recepção Ana');
    });
  });
}
