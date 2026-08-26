import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/matricula.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/plano.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/matriculas/matriculas_list_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_plano_service.dart';

const _adm = AppUser(
  uid: 'adm-1',
  nome: 'Dono',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);

const _recepcaoSemPermissao = AppUser(
  uid: 'func-1',
  nome: 'Recepção Ana',
  email: 'ana@exemplo.com',
  role: UserRole.funcionario,
  permissoes: {Permission.gerenciarAlunos},
);

const _carlos = AppUser(
  uid: 'aluno-carlos',
  nome: 'Carlos Souza',
  email: 'carlos@exemplo.com',
  role: UserRole.aluno,
);

const _planoMensal = Plano(id: 'plano-mensal', nome: 'Mensal', valor: 129.9, duracaoDias: 30);

Widget _wrap(FakeAlunoService alunoService, FakePlanoService planoService, AppUser staffAtual) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: MatriculasListScreen(
      alunoService: alunoService,
      planoService: planoService,
      staffAtual: staffAtual,
    ),
  );
}

void main() {
  testWidgets('lista as matriculas com aluno, plano e status', (tester) async {
    final alunoService = FakeAlunoService(
      alunos: const [_carlos],
      matriculas: [
        Matricula(
          id: 'm1',
          alunoId: _carlos.uid,
          planoId: _planoMensal.id!,
          dataInicio: DateTime(2026, 8, 1),
          dataVencimento: DateTime(2026, 9, 1),
          valorContratado: 129.9,
        ),
      ],
    );
    final planoService = FakePlanoService(planos: const [_planoMensal]);

    await tester.pumpWidget(_wrap(alunoService, planoService, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Carlos Souza'), findsOneWidget);
    expect(find.text('Mensal'), findsOneWidget);
    expect(find.text('Ativa'), findsOneWidget);
  });

  testWidgets('estado vazio mostra mensagem adequada', (tester) async {
    final alunoService = FakeAlunoService();
    final planoService = FakePlanoService();

    await tester.pumpWidget(_wrap(alunoService, planoService, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma matrícula encontrada.'), findsOneWidget);
  });

  testWidgets('ADM ve o botao de nova matricula e as acoes renovar/cancelar', (tester) async {
    final alunoService = FakeAlunoService(
      alunos: const [_carlos],
      matriculas: [
        Matricula(
          id: 'm1',
          alunoId: _carlos.uid,
          planoId: _planoMensal.id!,
          dataInicio: DateTime(2026, 8, 1),
          dataVencimento: DateTime(2026, 9, 1),
          valorContratado: 129.9,
        ),
      ],
    );
    final planoService = FakePlanoService(planos: const [_planoMensal]);

    await tester.pumpWidget(_wrap(alunoService, planoService, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Nova matrícula'), findsOneWidget);
    expect(find.text('RENOVAR'), findsOneWidget);
    expect(find.text('CANCELAR'), findsOneWidget);
  });

  testWidgets(
    'funcionario sem Permission.matriculas nao ve nenhuma acao de gestao',
    (tester) async {
      final alunoService = FakeAlunoService(
        alunos: const [_carlos],
        matriculas: [
          Matricula(
            id: 'm1',
            alunoId: _carlos.uid,
            planoId: _planoMensal.id!,
            dataInicio: DateTime(2026, 8, 1),
            dataVencimento: DateTime(2026, 9, 1),
            valorContratado: 129.9,
          ),
        ],
      );
      final planoService = FakePlanoService(planos: const [_planoMensal]);

      await tester.pumpWidget(_wrap(alunoService, planoService, _recepcaoSemPermissao));
      await tester.pumpAndSettle();

      expect(find.text('Nova matrícula'), findsNothing);
      expect(find.text('RENOVAR'), findsNothing);
      expect(find.text('CANCELAR'), findsNothing);
    },
  );

  testWidgets('matricula cancelada nao mostra o botao de cancelar', (tester) async {
    final alunoService = FakeAlunoService(
      alunos: const [_carlos],
      matriculas: [
        Matricula(
          id: 'm1',
          alunoId: _carlos.uid,
          planoId: _planoMensal.id!,
          dataInicio: DateTime(2026, 8, 1),
          dataVencimento: DateTime(2026, 9, 1),
          valorContratado: 129.9,
          status: StatusMatricula.cancelada,
        ),
      ],
    );
    final planoService = FakePlanoService(planos: const [_planoMensal]);

    await tester.pumpWidget(_wrap(alunoService, planoService, _adm));
    await tester.pumpAndSettle();

    expect(find.text('Cancelada'), findsOneWidget);
    expect(find.text('CANCELAR'), findsNothing);
    // Renovar continua disponivel mesmo numa matricula ja encerrada.
    expect(find.text('RENOVAR'), findsOneWidget);
  });

  testWidgets('tocar em cancelar chama AlunoService.cancelarMatricula apos confirmar', (
    tester,
  ) async {
    final alunoService = FakeAlunoService(
      alunos: const [_carlos],
      matriculas: [
        Matricula(
          id: 'm1',
          alunoId: _carlos.uid,
          planoId: _planoMensal.id!,
          dataInicio: DateTime(2026, 8, 1),
          dataVencimento: DateTime(2026, 9, 1),
          valorContratado: 129.9,
        ),
      ],
    );
    final planoService = FakePlanoService(planos: const [_planoMensal]);

    await tester.pumpWidget(_wrap(alunoService, planoService, _adm));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar matrícula'), findsOneWidget);
    await tester.tap(find.text('CANCELAR MATRÍCULA'));
    await tester.pumpAndSettle();

    expect(alunoService.ultimaMatriculaCanceladaId, 'm1');
  });
}
