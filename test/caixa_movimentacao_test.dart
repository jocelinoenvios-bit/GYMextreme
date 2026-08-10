import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/caixa_movimentacao.dart';

void main() {
  group('TipoMovimentacaoCaixa', () {
    test('fromFirestoreValue reconhece os 5 tipos', () {
      expect(
        TipoMovimentacaoCaixa.fromFirestoreValue('recebimento'),
        TipoMovimentacaoCaixa.recebimento,
      );
      expect(
        TipoMovimentacaoCaixa.fromFirestoreValue('suprimento'),
        TipoMovimentacaoCaixa.suprimento,
      );
      expect(
        TipoMovimentacaoCaixa.fromFirestoreValue('retirada'),
        TipoMovimentacaoCaixa.retirada,
      );
      expect(TipoMovimentacaoCaixa.fromFirestoreValue('ajuste'), TipoMovimentacaoCaixa.ajuste);
      expect(
        TipoMovimentacaoCaixa.fromFirestoreValue('pagamentoContaPagar'),
        TipoMovimentacaoCaixa.pagamentoContaPagar,
      );
    });

    test('fromFirestoreValue com valor desconhecido/nulo cai em ajuste', () {
      expect(TipoMovimentacaoCaixa.fromFirestoreValue(null), TipoMovimentacaoCaixa.ajuste);
      expect(TipoMovimentacaoCaixa.fromFirestoreValue('lixo'), TipoMovimentacaoCaixa.ajuste);
    });
  });

  group('CaixaMovimentacao', () {
    test('fromFirestore le todos os campos, incluindo referencia a ContaReceber', () {
      final mov = CaixaMovimentacao.fromFirestore('mov1', {
        'tipo': 'recebimento',
        'valor': 129.9,
        'formaPagamento': 'PIX',
        'descricao': 'Mensalidade agosto',
        'contaReceberAlunoId': 'aluno1',
        'contaReceberId': 'conta1',
        'staffUid': 'staff1',
        'staffNome': 'Recepção Ana',
        'criadoEm': Timestamp.fromDate(DateTime(2026, 8, 10)),
      });

      expect(mov.tipo, TipoMovimentacaoCaixa.recebimento);
      expect(mov.valor, 129.9);
      expect(mov.formaPagamento, 'PIX');
      expect(mov.contaReceberAlunoId, 'aluno1');
      expect(mov.contaReceberId, 'conta1');
      expect(mov.staffNome, 'Recepção Ana');
      expect(mov.criadoEm, DateTime(2026, 8, 10));
    });

    test('toFirestore preserva tipo e valor assinado', () {
      const retirada = CaixaMovimentacao(
        tipo: TipoMovimentacaoCaixa.retirada,
        valor: -50,
        staffUid: 'staff1',
        staffNome: 'Recepção Ana',
      );

      final dados = retirada.toFirestore();
      expect(dados['tipo'], 'retirada');
      expect(dados['valor'], -50);
    });

    test('fromFirestore le a referencia a ContaPagar', () {
      final mov = CaixaMovimentacao.fromFirestore('mov2', {
        'tipo': 'pagamentoContaPagar',
        'valor': -60,
        'contaPagarId': 'conta1',
        'staffUid': 'staff1',
        'staffNome': 'Recepção Ana',
      });

      expect(mov.tipo, TipoMovimentacaoCaixa.pagamentoContaPagar);
      expect(mov.valor, -60);
      expect(mov.contaPagarId, 'conta1');
    });
  });
}
