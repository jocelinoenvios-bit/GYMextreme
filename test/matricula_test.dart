import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/matricula.dart';

void main() {
  group('StatusMatricula', () {
    test('fromFirestoreValue reconhece os 4 status', () {
      expect(StatusMatricula.fromFirestoreValue('ativa'), StatusMatricula.ativa);
      expect(StatusMatricula.fromFirestoreValue('vencida'), StatusMatricula.vencida);
      expect(StatusMatricula.fromFirestoreValue('cancelada'), StatusMatricula.cancelada);
      expect(StatusMatricula.fromFirestoreValue('suspensa'), StatusMatricula.suspensa);
    });

    test('fromFirestoreValue com valor desconhecido/nulo cai em ativa', () {
      expect(StatusMatricula.fromFirestoreValue(null), StatusMatricula.ativa);
      expect(StatusMatricula.fromFirestoreValue('lixo'), StatusMatricula.ativa);
    });
  });

  group('Matricula', () {
    test('fromFirestore le todos os campos', () {
      final matricula = Matricula.fromFirestore('m1', {
        'alunoId': 'aluno1',
        'planoId': 'plano1',
        'dataInicio': Timestamp.fromDate(DateTime(2026, 8, 1)),
        'dataVencimento': Timestamp.fromDate(DateTime(2026, 9, 1)),
        'status': 'ativa',
        'valorContratado': 129.9,
        'formaPagamento': 'PIX',
        'observacao': 'Primeira matrícula',
        'criadoEm': Timestamp.fromDate(DateTime(2026, 8, 1)),
      });

      expect(matricula.alunoId, 'aluno1');
      expect(matricula.planoId, 'plano1');
      expect(matricula.dataInicio, DateTime(2026, 8, 1));
      expect(matricula.dataVencimento, DateTime(2026, 9, 1));
      expect(matricula.status, StatusMatricula.ativa);
      expect(matricula.valorContratado, 129.9);
      expect(matricula.formaPagamento, 'PIX');
      expect(matricula.observacao, 'Primeira matrícula');
    });

    test('toFirestore preserva alunoId, planoId e status', () {
      final matricula = Matricula(
        alunoId: 'aluno1',
        planoId: 'plano1',
        dataInicio: DateTime(2026, 8, 1),
        dataVencimento: DateTime(2026, 9, 1),
        valorContratado: 129.9,
      );

      final dados = matricula.toFirestore();
      expect(dados['alunoId'], 'aluno1');
      expect(dados['planoId'], 'plano1');
      expect(dados['status'], 'ativa');
      expect(dados['valorContratado'], 129.9);
    });

    test('copyWith troca status sem afetar os demais campos', () {
      final matricula = Matricula(
        alunoId: 'aluno1',
        planoId: 'plano1',
        dataInicio: DateTime(2026, 8, 1),
        dataVencimento: DateTime(2026, 9, 1),
        valorContratado: 129.9,
      );

      final cancelada = matricula.copyWith(status: StatusMatricula.cancelada);

      expect(cancelada.status, StatusMatricula.cancelada);
      expect(cancelada.alunoId, 'aluno1');
      expect(cancelada.valorContratado, 129.9);
    });
  });
}
