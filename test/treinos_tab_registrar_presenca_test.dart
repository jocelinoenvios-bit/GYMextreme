import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/treino.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/tabs/treinos_tab.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

const _adm = AppUser(
  uid: 'adm-1',
  nome: 'Admin Teste',
  email: 'adm@teste.com',
  role: UserRole.adm,
);

const _aluno = AppUser(
  uid: 'aluno-2',
  nome: 'Aluno Sem Permissão',
  email: 'aluno@teste.com',
  role: UserRole.aluno,
);

void main() {
  group('TreinosTab — registrar presença/falta (staff)', () {
    testWidgets('staff com permissão registra presença/falta pelo menu do card', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: [const Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1)],
      );

      await tester.pumpWidget(
        _wrap(TreinosTab(uid: 'aluno-1', alunoService: alunoService, staffAtual: _adm)),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Registrar presença/falta'), findsOneWidget);

      await tester.tap(find.text('Registrar presença/falta'));
      await tester.pumpAndSettle();

      expect(find.text('Presença — Treino A'), findsOneWidget);

      await tester.tap(find.text('Falta'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('SALVAR'));
      await tester.pumpAndSettle();

      expect(alunoService.ultimoHistoricoRegistrado, isNotNull);
      expect(alunoService.ultimoHistoricoRegistrado!.treinoId, 'treino-a');
      expect(alunoService.ultimoHistoricoRegistrado!.status.name, 'falta');
      expect(alunoService.ultimoHistoricoRegistrado!.registradoPorUid, 'adm-1');
    });

    testWidgets('o próprio aluno nunca vê a opção de registrar presença (sem permissão de staff)', (
      tester,
    ) async {
      final alunoService = FakeAlunoService(
        treinos: [const Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1)],
      );

      await tester.pumpWidget(
        _wrap(TreinosTab(uid: 'aluno-1', alunoService: alunoService, staffAtual: _aluno)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.more_vert), findsNothing);
    });
  });
}
