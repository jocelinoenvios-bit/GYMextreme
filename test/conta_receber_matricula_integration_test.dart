import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/matricula.dart';

import 'support/fake_aluno_service.dart';

void main() {
  group('AlunoService.criarContaReceberDeMatricula (integração)', () {
    test('copia valor, vencimento e forma de pagamento da matrícula', () async {
      final service = FakeAlunoService();
      final matricula = Matricula(
        id: 'm1',
        alunoId: 'aluno1',
        planoId: 'plano1',
        dataInicio: DateTime(2026, 8, 1),
        dataVencimento: DateTime(2026, 9, 1),
        valorContratado: 349,
        formaPagamento: 'PIX',
      );

      final id = await service.criarContaReceberDeMatricula(
        'aluno1',
        matricula,
        staffUid: 'staff1',
        staffNome: 'Recepção Ana',
      );

      final conta = service.contasReceber.single;
      expect(conta.id, id);
      expect(conta.alunoId, 'aluno1');
      expect(conta.matriculaId, 'm1');
      expect(conta.valorOriginal, 349);
      expect(conta.vencimento, DateTime(2026, 9, 1));
      expect(conta.formaPagamento, 'PIX');
      expect(conta.criadoPorNome, 'Recepção Ana');
    });

    test('nao duplica nem altera nenhum campo da matricula original', () async {
      final service = FakeAlunoService();
      final matricula = Matricula(
        id: 'm1',
        alunoId: 'aluno1',
        planoId: 'plano1',
        dataInicio: DateTime(2026, 8, 1),
        dataVencimento: DateTime(2026, 9, 1),
        valorContratado: 349,
      );

      await service.criarContaReceberDeMatricula(
        'aluno1',
        matricula,
        staffUid: 'staff1',
        staffNome: 'Recepção Ana',
      );

      // O objeto Matricula passado nao tem nenhum metodo mutavel — a
      // unica forma de "alterar" seria via AlunoService.criarMatricula/
      // cancelarMatricula, nenhum dos quais foi chamado aqui.
      expect(service.matriculas, isEmpty);
      expect(matricula.valorContratado, 349);
    });

    test('varias contas podem referenciar a mesma matricula, sem duplicar dados', () async {
      final service = FakeAlunoService();
      final matricula = Matricula(
        id: 'm1',
        alunoId: 'aluno1',
        planoId: 'plano1',
        dataInicio: DateTime(2026, 8, 1),
        dataVencimento: DateTime(2026, 9, 1),
        valorContratado: 129.9,
      );

      await service.criarContaReceberDeMatricula(
        'aluno1',
        matricula,
        descricao: 'Mensalidade agosto',
        staffUid: 'staff1',
        staffNome: 'Recepção Ana',
      );
      await service.criarContaReceberDeMatricula(
        'aluno1',
        matricula,
        descricao: 'Mensalidade setembro',
        staffUid: 'staff1',
        staffNome: 'Recepção Ana',
      );

      expect(service.contasReceber, hasLength(2));
      expect(service.contasReceber.every((c) => c.matriculaId == 'm1'), isTrue);
    });
  });
}
