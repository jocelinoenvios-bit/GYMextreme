import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/conta_receber.dart';

void main() {
  group('StatusContaReceber', () {
    test('fromFirestoreValue reconhece os 4 status', () {
      expect(StatusContaReceber.fromFirestoreValue('pendente'), StatusContaReceber.pendente);
      expect(StatusContaReceber.fromFirestoreValue('pago'), StatusContaReceber.pago);
      expect(StatusContaReceber.fromFirestoreValue('vencido'), StatusContaReceber.vencido);
      expect(StatusContaReceber.fromFirestoreValue('cancelado'), StatusContaReceber.cancelado);
    });

    test('fromFirestoreValue com valor desconhecido/nulo cai em pendente', () {
      expect(StatusContaReceber.fromFirestoreValue(null), StatusContaReceber.pendente);
      expect(StatusContaReceber.fromFirestoreValue('lixo'), StatusContaReceber.pendente);
    });
  });

  group('ContaReceber.valorLiquido', () {
    test('sem desconto nem juros, e igual ao valor original', () {
      final conta = ContaReceber(
        alunoId: 'a1',
        descricao: 'Mensalidade',
        valorOriginal: 100,
        vencimento: DateTime(2026, 9, 1),
      );
      expect(conta.valorLiquido, 100);
    });

    test('desconto reduz o valor liquido', () {
      final conta = ContaReceber(
        alunoId: 'a1',
        descricao: 'Mensalidade',
        valorOriginal: 100,
        desconto: 20,
        vencimento: DateTime(2026, 9, 1),
      );
      expect(conta.valorLiquido, 80);
    });

    test('juros/multa aumentam o valor liquido', () {
      final conta = ContaReceber(
        alunoId: 'a1',
        descricao: 'Mensalidade',
        valorOriginal: 100,
        jurosMulta: 15,
        vencimento: DateTime(2026, 9, 1),
      );
      expect(conta.valorLiquido, 115);
    });

    test('desconto maior que o valor original nunca fica negativo', () {
      final conta = ContaReceber(
        alunoId: 'a1',
        descricao: 'Mensalidade',
        valorOriginal: 50,
        desconto: 200,
        vencimento: DateTime(2026, 9, 1),
      );
      expect(conta.valorLiquido, 0);
    });
  });

  group('ContaReceber.saldoDevedor', () {
    test('sem nenhum pagamento, o saldo e o valor liquido inteiro', () {
      final conta = ContaReceber(
        alunoId: 'a1',
        descricao: 'Mensalidade',
        valorOriginal: 100,
        vencimento: DateTime(2026, 9, 1),
      );
      expect(conta.saldoDevedor, 100);
    });

    test('pagamento parcial deixa saldo positivo', () {
      final conta = ContaReceber(
        alunoId: 'a1',
        descricao: 'Mensalidade',
        valorOriginal: 100,
        valorPago: 60,
        vencimento: DateTime(2026, 9, 1),
      );
      expect(conta.saldoDevedor, 40);
    });

    test('pagamento maior que o valor liquido deixa saldo negativo (pago a mais)', () {
      final conta = ContaReceber(
        alunoId: 'a1',
        descricao: 'Mensalidade',
        valorOriginal: 100,
        valorPago: 120,
        vencimento: DateTime(2026, 9, 1),
      );
      expect(conta.saldoDevedor, -20);
    });
  });

  group('ContaReceber.fromFirestore / toFirestore', () {
    test('fromFirestore le todos os campos, incluindo vinculo com matricula', () {
      final conta = ContaReceber.fromFirestore('conta1', {
        'alunoId': 'aluno1',
        'matriculaId': 'matricula1',
        'descricao': 'Mensalidade agosto',
        'valorOriginal': 129.9,
        'valorPago': 129.9,
        'desconto': 10,
        'jurosMulta': 0,
        'vencimento': Timestamp.fromDate(DateTime(2026, 8, 10)),
        'dataPagamento': Timestamp.fromDate(DateTime(2026, 8, 5)),
        'status': 'pago',
        'formaPagamento': 'PIX',
        'observacao': 'Pago adiantado',
        'criadoPorUid': 'staff1',
        'criadoPorNome': 'Recepção Ana',
        'recebidoPorUid': 'staff1',
        'recebidoPorNome': 'Recepção Ana',
      });

      expect(conta.alunoId, 'aluno1');
      expect(conta.matriculaId, 'matricula1');
      expect(conta.descricao, 'Mensalidade agosto');
      expect(conta.valorOriginal, 129.9);
      expect(conta.valorPago, 129.9);
      expect(conta.desconto, 10);
      expect(conta.vencimento, DateTime(2026, 8, 10));
      expect(conta.dataPagamento, DateTime(2026, 8, 5));
      expect(conta.status, StatusContaReceber.pago);
      expect(conta.formaPagamento, 'PIX');
      expect(conta.recebidoPorNome, 'Recepção Ana');
    });

    test('fromFirestore usa padroes razoaveis pra documento incompleto', () {
      final conta = ContaReceber.fromFirestore('conta2', const {});
      expect(conta.descricao, 'Cobrança');
      expect(conta.valorOriginal, 0);
      expect(conta.desconto, 0);
      expect(conta.jurosMulta, 0);
      expect(conta.status, StatusContaReceber.pendente);
      expect(conta.valorPago, isNull);
      expect(conta.matriculaId, isNull);
    });

    test('toFirestore preserva os campos principais', () {
      final conta = ContaReceber(
        alunoId: 'aluno1',
        matriculaId: 'matricula1',
        descricao: 'Mensalidade',
        valorOriginal: 129.9,
        vencimento: DateTime(2026, 9, 1),
      );

      final dados = conta.toFirestore();
      expect(dados['alunoId'], 'aluno1');
      expect(dados['matriculaId'], 'matricula1');
      expect(dados['descricao'], 'Mensalidade');
      expect(dados['valorOriginal'], 129.9);
      expect(dados['status'], 'pendente');
      expect(dados['valorPago'], isNull);
    });
  });

  group('ContaReceber.copyWith', () {
    test('registrar pagamento so troca os campos do recebimento', () {
      final conta = ContaReceber(
        id: 'conta1',
        alunoId: 'aluno1',
        descricao: 'Mensalidade',
        valorOriginal: 129.9,
        vencimento: DateTime(2026, 9, 1),
      );

      final paga = conta.copyWith(
        status: StatusContaReceber.pago,
        valorPago: 129.9,
        dataPagamento: DateTime(2026, 8, 28),
        formaPagamento: 'PIX',
        recebidoPorUid: 'staff1',
        recebidoPorNome: 'Recepção Ana',
      );

      expect(paga.status, StatusContaReceber.pago);
      expect(paga.valorPago, 129.9);
      expect(paga.descricao, 'Mensalidade');
      expect(paga.valorOriginal, 129.9);
      expect(paga.recebidoPorNome, 'Recepção Ana');
    });
  });
}
