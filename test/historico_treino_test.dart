import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/historico_treino.dart';

void main() {
  group('HistoricoTreino', () {
    test('toFirestore/fromFirestore preserva os dados principais', () {
      final registro = HistoricoTreino(
        id: 'reg-1',
        treinoId: 'treino-a',
        data: DateTime(2026, 3, 10),
        diaSemana: 2,
        status: StatusHistoricoTreino.realizado,
        observacoes: 'Treino completo',
        registradoPorUid: 'staff-1',
        registradoPorNome: 'Personal Teste',
      );

      final dados = registro.toFirestore();
      final reconstruido = HistoricoTreino.fromFirestore('reg-1', {
        ...dados,
        // toFirestore() usa FieldValue.serverTimestamp() pra registradoEm,
        // que não existe fora do Firestore de verdade — o round-trip do
        // teste simula o que o servidor devolveria depois de gravar.
        'registradoPorUid': 'staff-1',
        'registradoPorNome': 'Personal Teste',
      });

      expect(reconstruido.treinoId, 'treino-a');
      expect(reconstruido.data, DateTime(2026, 3, 10));
      expect(reconstruido.diaSemana, 2);
      expect(reconstruido.status, StatusHistoricoTreino.realizado);
      expect(reconstruido.observacoes, 'Treino completo');
      expect(reconstruido.registradoPorUid, 'staff-1');
      expect(reconstruido.registradoPorNome, 'Personal Teste');
    });

    test('status falta é preservado (não confundido com ausência de registro)', () {
      final registro = HistoricoTreino(
        treinoId: 'treino-b',
        data: DateTime(2026, 3, 11),
        diaSemana: 3,
        status: StatusHistoricoTreino.falta,
      );

      final dados = registro.toFirestore();
      final reconstruido = HistoricoTreino.fromFirestore('reg-2', dados);

      expect(reconstruido.status, StatusHistoricoTreino.falta);
      expect(reconstruido.status.label, 'Falta');
    });

    test('fromFirestore com status desconhecido/ausente cai em falta, nunca quebra', () {
      final reconstruido = HistoricoTreino.fromFirestore('reg-3', {
        'treinoId': 'treino-c',
        'diaSemana': 1,
      });

      expect(reconstruido.status, StatusHistoricoTreino.falta);
    });
  });
}
