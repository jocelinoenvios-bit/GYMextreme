import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/caixa.dart';

void main() {
  group('StatusCaixa', () {
    test('fromFirestoreValue reconhece aberto e fechado', () {
      expect(StatusCaixa.fromFirestoreValue('aberto'), StatusCaixa.aberto);
      expect(StatusCaixa.fromFirestoreValue('fechado'), StatusCaixa.fechado);
    });

    test('fromFirestoreValue com valor desconhecido/nulo cai em aberto', () {
      expect(StatusCaixa.fromFirestoreValue(null), StatusCaixa.aberto);
      expect(StatusCaixa.fromFirestoreValue('lixo'), StatusCaixa.aberto);
    });
  });

  group('Caixa', () {
    test('fromFirestore le todos os campos de uma abertura simples', () {
      final caixa = Caixa.fromFirestore('c1', {
        'valorInicial': 100,
        'status': 'aberto',
        'abertoPorUid': 'staff1',
        'abertoPorNome': 'Recepção Ana',
        'abertoEm': Timestamp.fromDate(DateTime(2026, 8, 10, 8)),
      });

      expect(caixa.valorInicial, 100);
      expect(caixa.status, StatusCaixa.aberto);
      expect(caixa.abertoPorNome, 'Recepção Ana');
      expect(caixa.abertoEm, DateTime(2026, 8, 10, 8));
      expect(caixa.valorContado, isNull);
      expect(caixa.diferenca, isNull);
    });

    test('fromFirestore le os campos de fechamento quando presentes', () {
      final caixa = Caixa.fromFirestore('c1', {
        'valorInicial': 100,
        'status': 'fechado',
        'abertoPorUid': 'staff1',
        'abertoPorNome': 'Recepção Ana',
        'valorContado': 480,
        'valorEsperadoNoFechamento': 500,
        'diferenca': -20,
        'fechadoPorUid': 'staff2',
        'fechadoPorNome': 'Recepção Bia',
        'fechadoEm': Timestamp.fromDate(DateTime(2026, 8, 10, 18)),
        'observacaoFechamento': 'Faltou trocar 20 reais',
      });

      expect(caixa.status, StatusCaixa.fechado);
      expect(caixa.valorContado, 480);
      expect(caixa.valorEsperadoNoFechamento, 500);
      expect(caixa.diferenca, -20);
      expect(caixa.fechadoPorNome, 'Recepção Bia');
      expect(caixa.observacaoFechamento, 'Faltou trocar 20 reais');
    });

    test('toFirestore preserva valorInicial e status', () {
      const caixa = Caixa(
        valorInicial: 100,
        abertoPorUid: 'staff1',
        abertoPorNome: 'Recepção Ana',
      );

      final dados = caixa.toFirestore();
      expect(dados['valorInicial'], 100);
      expect(dados['status'], 'aberto');
      expect(dados['valorContado'], isNull);
    });
  });
}
