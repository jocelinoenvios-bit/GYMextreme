import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/termo_aceite.dart';

void main() {
  group('TermoAceite', () {
    test('naoAceito e o estado padrao antes de qualquer aceite', () {
      expect(TermoAceite.naoAceito.aceito, isFalse);
      expect(TermoAceite.naoAceito.nomeAssinatura, isNull);
    });

    test('fromFirestore le aceite completo, incluindo quem registrou e o responsavel', () {
      final termo = TermoAceite.fromFirestore({
        'aceito': true,
        'aceitoEm': Timestamp.fromDate(DateTime(2026, 8, 4, 14, 30)),
        'nomeAssinatura': 'Maria Silva',
        'responsavel': 'João Silva (pai)',
        'versaoRegulamento': '2026-08-03',
        'registradoPorUid': 'staff1',
        'registradoPorNome': 'Recepção Ana',
      });

      expect(termo.aceito, isTrue);
      expect(termo.aceitoEm, DateTime(2026, 8, 4, 14, 30));
      expect(termo.nomeAssinatura, 'Maria Silva');
      expect(termo.responsavel, 'João Silva (pai)');
      expect(termo.versaoRegulamento, '2026-08-03');
      expect(termo.registradoPorNome, 'Recepção Ana');
    });

    test('documento sem campo aceito e tratado como nao aceito', () {
      final termo = TermoAceite.fromFirestore(const {});
      expect(termo.aceito, isFalse);
    });

    test('toFirestore preserva nome, responsavel e quem registrou', () {
      const termo = TermoAceite(
        aceito: true,
        nomeAssinatura: 'Maria Silva',
        responsavel: 'João Silva (pai)',
        versaoRegulamento: '2026-08-03',
        registradoPorUid: 'staff1',
        registradoPorNome: 'Recepção Ana',
      );

      final dados = termo.toFirestore();
      expect(dados['aceito'], isTrue);
      expect(dados['nomeAssinatura'], 'Maria Silva');
      expect(dados['responsavel'], 'João Silva (pai)');
      expect(dados['registradoPorNome'], 'Recepção Ana');
    });
  });
}
