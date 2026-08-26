import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/movimentacao_estoque.dart';

void main() {
  group('TipoMovimentacaoEstoque', () {
    test('fromFirestoreValue reconhece os 3 tipos', () {
      expect(
        TipoMovimentacaoEstoque.fromFirestoreValue('entrada'),
        TipoMovimentacaoEstoque.entrada,
      );
      expect(TipoMovimentacaoEstoque.fromFirestoreValue('saida'), TipoMovimentacaoEstoque.saida);
      expect(
        TipoMovimentacaoEstoque.fromFirestoreValue('ajuste'),
        TipoMovimentacaoEstoque.ajuste,
      );
    });

    test('fromFirestoreValue com valor desconhecido/nulo cai em ajuste', () {
      expect(TipoMovimentacaoEstoque.fromFirestoreValue(null), TipoMovimentacaoEstoque.ajuste);
      expect(TipoMovimentacaoEstoque.fromFirestoreValue('lixo'), TipoMovimentacaoEstoque.ajuste);
    });
  });

  group('MovimentacaoEstoque', () {
    test('fromFirestore le todos os campos, incluindo anterior/posterior', () {
      final mov = MovimentacaoEstoque.fromFirestore('mov1', {
        'tipo': 'entrada',
        'quantidade': 10,
        'estoqueAnterior': 5,
        'estoquePosterior': 15,
        'motivo': 'Reposição mensal',
        'staffUid': 'staff1',
        'staffNome': 'Recepção Ana',
        'criadoEm': Timestamp.fromDate(DateTime(2026, 8, 10)),
      });

      expect(mov.tipo, TipoMovimentacaoEstoque.entrada);
      expect(mov.quantidade, 10);
      expect(mov.estoqueAnterior, 5);
      expect(mov.estoquePosterior, 15);
      expect(mov.motivo, 'Reposição mensal');
      expect(mov.staffNome, 'Recepção Ana');
      expect(mov.criadoEm, DateTime(2026, 8, 10));
    });

    test('toFirestore preserva tipo e quantidade assinada', () {
      const saida = MovimentacaoEstoque(
        tipo: TipoMovimentacaoEstoque.saida,
        quantidade: -3,
        estoqueAnterior: 10,
        estoquePosterior: 7,
        staffUid: 'staff1',
        staffNome: 'Recepção Ana',
      );

      final dados = saida.toFirestore();
      expect(dados['tipo'], 'saida');
      expect(dados['quantidade'], -3);
      expect(dados['estoqueAnterior'], 10);
      expect(dados['estoquePosterior'], 7);
    });
  });
}
