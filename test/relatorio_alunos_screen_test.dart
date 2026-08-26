import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/relatorios/relatorio_alunos_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/test_viewport.dart';

Widget _wrap(FakeAlunoService service) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: RelatorioAlunosScreen(alunoService: service),
  );
}

void main() {
  testWidgets('estado vazio mostra zeros e nao quebra', (tester) async {
    await tester.pumpWidget(_wrap(FakeAlunoService()));
    await tester.pumpAndSettle();

    expect(find.text('Relatório de alunos'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
  });

  testWidgets('mostra aluno bloqueado e aluno sem registro com status corretos', (
    tester,
  ) async {
    usarViewportGrande(tester);
    final hoje = DateTime(2026, 8, 10);
    final service = FakeAlunoService(
      alunos: [
        const AppUser(
          uid: 'a1',
          nome: 'Bloqueado Bia',
          email: 'bia@exemplo.com',
          role: UserRole.aluno,
        ),
        const AppUser(
          uid: 'a2',
          nome: 'Sem Ficha Carlos',
          email: 'carlos@exemplo.com',
          role: UserRole.aluno,
        ),
      ],
      fichasAlunos: [
        Aluno(uid: 'a1', proximoVencimento: hoje.subtract(const Duration(days: 30))),
      ],
    );

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('Bloqueado Bia'), findsOneWidget);
    expect(find.text('Sem Ficha Carlos'), findsOneWidget);
    expect(find.text('Bloqueado'), findsOneWidget);
    expect(find.text('Sem registro'), findsWidgets);
  });

  testWidgets('novos cadastros conta apenas alunos dentro do periodo selecionado', (
    tester,
  ) async {
    final service = FakeAlunoService(
      alunos: [
        const AppUser(
          uid: 'a1',
          nome: 'Aluno Antigo',
          email: 'antigo@exemplo.com',
          role: UserRole.aluno,
          criadoEm: null,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.textContaining('cadastrado(s) no período selecionado'), findsOneWidget);
  });
}
