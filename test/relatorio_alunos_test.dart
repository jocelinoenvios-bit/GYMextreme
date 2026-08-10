import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/utils/relatorio_alunos.dart';
import 'package:gymextreme_app/utils/status_acesso.dart';

final _hoje = DateTime(2026, 8, 10);

AppUser _aluno(String uid, {DateTime? criadoEm}) => AppUser(
  uid: uid,
  nome: 'Aluno $uid',
  email: '$uid@x.com',
  role: UserRole.aluno,
  criadoEm: criadoEm,
);

void main() {
  group('calcularResumoAlunos', () {
    test('lista vazia da resumo zerado', () {
      final resumo = calcularResumoAlunos(alunos: const [], fichasAlunos: const [], hoje: _hoje);
      expect(resumo.total, 0);
      expect(resumo.ativos, 0);
      expect(resumo.bloqueados, 0);
      expect(resumo.semRegistro, 0);
    });

    test('separa ativos, bloqueados e sem registro', () {
      final resumo = calcularResumoAlunos(
        alunos: [_aluno('a1'), _aluno('a2'), _aluno('a3')],
        fichasAlunos: [
          Aluno(uid: 'a1', proximoVencimento: DateTime(2026, 12, 1)),
          Aluno(uid: 'a2', proximoVencimento: DateTime(2020, 1, 1)),
          // a3 sem ficha nenhuma
        ],
        hoje: _hoje,
      );

      expect(resumo.total, 3);
      expect(resumo.ativos, 1);
      expect(resumo.bloqueados, 1);
      expect(resumo.semRegistro, 1);
    });

    test('tolerancia conta como ativo, nao como bloqueado', () {
      final resumo = calcularResumoAlunos(
        alunos: [_aluno('a1')],
        // vencimento ontem: dentro da tolerancia (nao bloqueado ainda).
        fichasAlunos: [Aluno(uid: 'a1', proximoVencimento: DateTime(2026, 8, 9))],
        hoje: _hoje,
      );

      expect(resumo.ativos, 1);
      expect(resumo.bloqueados, 0);
    });
  });

  group('calcularStatusMensalidadeAluno', () {
    test('aluno sem ficha cai em semRegistro', () {
      final status = calcularStatusMensalidadeAluno(_aluno('a1'), const {}, hoje: _hoje);
      expect(status, StatusMensalidade.semRegistro);
    });
  });

  group('filtrarAlunosPorPeriodoDeCadastro', () {
    final alunos = [
      _aluno('a1', criadoEm: DateTime(2026, 7, 1)),
      _aluno('a2', criadoEm: DateTime(2026, 8, 5)),
      _aluno('a3', criadoEm: DateTime(2026, 9, 1)),
    ];

    test('sem periodo, retorna todos', () {
      expect(filtrarAlunosPorPeriodoDeCadastro(alunos), hasLength(3));
    });

    test('filtra pelo intervalo de cadastro', () {
      final filtrados = filtrarAlunosPorPeriodoDeCadastro(
        alunos,
        de: DateTime(2026, 8, 1),
        ate: DateTime(2026, 8, 31),
      );
      expect(filtrados, hasLength(1));
      expect(filtrados.single.uid, 'a2');
    });

    test('aluno sem criadoEm nao aparece quando ha filtro de periodo', () {
      final comSemData = [..._alunosComSemData()];
      final filtrados = filtrarAlunosPorPeriodoDeCadastro(
        comSemData,
        de: DateTime(2026, 1, 1),
        ate: DateTime(2026, 12, 31),
      );
      expect(filtrados, isEmpty);
    });
  });
}

List<AppUser> _alunosComSemData() => [_aluno('legado')];
