import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/avaliacao_fisica.dart';

void main() {
  group('AvaliacaoFisica', () {
    test('fromFirestore/toFirestore fazem round-trip com peso, altura e circunferencias', () {
      final avaliacao = AvaliacaoFisica.fromFirestore('aval1', {
        'data': Timestamp.fromDate(DateTime(2026, 8, 4)),
        'pesoKg': 82.5,
        'alturaM': 1.78,
        'circunferenciasCm': {'peito': 102.0, 'cintura': 88.0},
        'observacoes': 'Evoluindo bem',
        'fotoUrls': ['https://exemplo.com/foto1.jpg'],
      });

      expect(avaliacao.id, 'aval1');
      expect(avaliacao.data, DateTime(2026, 8, 4));
      expect(avaliacao.pesoKg, 82.5);
      expect(avaliacao.alturaM, 1.78);
      expect(avaliacao.circunferenciasCm['peito'], 102.0);
      expect(avaliacao.fotoUrls, ['https://exemplo.com/foto1.jpg']);

      final dados = avaliacao.toFirestore();
      expect(dados['pesoKg'], 82.5);
      expect((dados['circunferenciasCm'] as Map)['cintura'], 88.0);
    });

    test('imc e calculado a partir de peso e altura', () {
      final avaliacao = AvaliacaoFisica(data: DateTime(2026, 8, 4), pesoKg: 80, alturaM: 2);
      expect(avaliacao.imc, 20);
    });

    test('imc e null quando falta peso ou altura', () {
      final semPeso = AvaliacaoFisica(data: DateTime(2026, 8, 4), alturaM: 1.8);
      final semAltura = AvaliacaoFisica(data: DateTime(2026, 8, 4), pesoKg: 80);
      expect(semPeso.imc, isNull);
      expect(semAltura.imc, isNull);
    });

    test('sem data no Firestore, usa a data atual em vez de lançar', () {
      final avaliacao = AvaliacaoFisica.fromFirestore('aval2', const {});
      expect(avaliacao.data, isNotNull);
      expect(avaliacao.circunferenciasCm, isEmpty);
      expect(avaliacao.fotoUrls, isEmpty);
    });
  });
}
