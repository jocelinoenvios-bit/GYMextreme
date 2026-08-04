import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/anamnese.dart';

void main() {
  group('Anamnese', () {
    test('fromFirestore/toFirestore fazem round-trip com todas as 13 perguntas', () {
      final anamnese = Anamnese.fromFirestore({
        'diasPorSemana': 4,
        'objetivo': 'hipertrofia',
        'situacaoMusculacao': 'nao',
        'tempoParadoMusculacao': '6 meses',
        'problemaColunaJoelho': true,
        'problemaColunaJoelhoQual': 'Hérnia de disco',
        'pressaoArterial': 'normal',
        'condicoesClinicas': ['hipertenso'],
        'alergia': true,
        'alergiaQual': 'Dipirona',
        'doresCorpo': false,
        'lesaoOsteoMuscular': false,
        'cirurgiaRecente': false,
        'usaMedicamento': true,
        'usaMedicamentoQual': 'Losartana',
        'usoSubstancias': ['alcool'],
        'fazendoDieta': true,
        'dietaPorContaPropria': false,
        'dietaOrientacaoNutricionista': true,
        'respondidoEm': Timestamp.fromDate(DateTime(2026, 8, 4)),
      });

      expect(anamnese.diasPorSemana, 4);
      expect(anamnese.objetivo, ObjetivoTreino.hipertrofia);
      expect(anamnese.situacaoMusculacao, SituacaoMusculacao.nao);
      expect(anamnese.pressaoArterial, NivelPressaoArterial.normal);
      expect(anamnese.condicoesClinicas, ['hipertenso']);
      expect(anamnese.usoSubstancias, ['alcool']);
      expect(anamnese.respondidoEm, DateTime(2026, 8, 4));

      final dados = anamnese.toFirestore();
      expect(dados['objetivo'], 'hipertrofia');
      expect(dados['condicoesClinicas'], ['hipertenso']);
    });

    test('campos ausentes no Firestore viram null/lista vazia, sem quebrar', () {
      final anamnese = Anamnese.fromFirestore(const {});

      expect(anamnese.diasPorSemana, isNull);
      expect(anamnese.objetivo, isNull);
      expect(anamnese.condicoesClinicas, isEmpty);
      expect(anamnese.usoSubstancias, isEmpty);
      expect(anamnese.respondidoEm, isNull);
    });

    test('valor de enum desconhecido (ficha antiga/corrompida) vira null em vez de lançar', () {
      final anamnese = Anamnese.fromFirestore(const {'objetivo': 'algo-que-nao-existe-mais'});
      expect(anamnese.objetivo, isNull);
    });
  });
}
