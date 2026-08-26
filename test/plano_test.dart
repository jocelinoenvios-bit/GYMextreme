import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/plano.dart';

void main() {
  group('Plano', () {
    test('fromFirestore le todos os campos', () {
      final plano = Plano.fromFirestore('plano1', {
        'nome': 'Mensal',
        'descricao': 'Acesso ilimitado, sem fidelidade',
        'valor': 129.9,
        'duracaoDias': 30,
        'ativo': true,
        'criadoEm': Timestamp.fromDate(DateTime(2026, 8, 1)),
        'atualizadoEm': Timestamp.fromDate(DateTime(2026, 8, 2)),
      });

      expect(plano.id, 'plano1');
      expect(plano.nome, 'Mensal');
      expect(plano.descricao, 'Acesso ilimitado, sem fidelidade');
      expect(plano.valor, 129.9);
      expect(plano.duracaoDias, 30);
      expect(plano.ativo, isTrue);
      expect(plano.criadoEm, DateTime(2026, 8, 1));
      expect(plano.atualizadoEm, DateTime(2026, 8, 2));
    });

    test('fromFirestore usa padroes razoaveis pra documento incompleto', () {
      final plano = Plano.fromFirestore('plano2', const {});

      expect(plano.nome, 'Plano');
      expect(plano.descricao, isNull);
      expect(plano.valor, 0);
      expect(plano.duracaoDias, 30);
      expect(plano.ativo, isTrue);
    });

    test('toFirestore preserva nome, valor e duracao', () {
      const plano = Plano(nome: 'Trimestral', valor: 349, duracaoDias: 90);

      final dados = plano.toFirestore();
      expect(dados['nome'], 'Trimestral');
      expect(dados['valor'], 349);
      expect(dados['duracaoDias'], 90);
      expect(dados['ativo'], isTrue);
    });

    test('copyWith troca so os campos informados', () {
      const plano = Plano(nome: 'Mensal', valor: 129.9, duracaoDias: 30);

      final atualizado = plano.copyWith(valor: 139.9, ativo: false);

      expect(atualizado.nome, 'Mensal');
      expect(atualizado.valor, 139.9);
      expect(atualizado.duracaoDias, 30);
      expect(atualizado.ativo, isFalse);
    });
  });
}
