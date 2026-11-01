import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/treino.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/treino_form_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

const _staff = AppUser(
  uid: 'staff-1',
  nome: 'Personal Teste',
  email: 'personal@teste.com',
  role: UserRole.personal,
);

// O formulário tem mais campos do que cabem no viewport padrão de teste —
// sem rolar até o botão primeiro, tap() acerta um ponto fora da tela.
Future<void> _tocarSalvar(WidgetTester tester) async {
  final botao = find.text('SALVAR TREINO');
  await tester.dragUntilVisible(botao, find.byType(ListView), const Offset(0, -300));
  await tester.tap(botao);
}

void main() {
  group('TreinoFormScreen — dia da semana/objetivo/vigência', () {
    testWidgets('salvar um treino novo grava o dia da semana e o objetivo escolhidos', (
      tester,
    ) async {
      final alunoService = FakeAlunoService();

      await tester.pumpWidget(
        _wrap(
          TreinoFormScreen(alunoUid: 'aluno-1', alunoService: alunoService, staffAtual: _staff),
        ),
      );
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'Nome do treino'), 'Treino A');
      await tester.enterText(find.widgetWithText(TextField, 'Objetivo'), 'Hipertrofia');

      await tester.tap(find.widgetWithText(DropdownButtonFormField<int?>, 'Sem dia definido'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Segunda').last);
      await tester.pumpAndSettle();

      await _tocarSalvar(tester);
      await tester.pumpAndSettle();

      expect(alunoService.treinos, hasLength(1));
      final salvo = alunoService.treinos.single;
      expect(salvo.nome, 'Treino A');
      expect(salvo.objetivo, 'Hipertrofia');
      expect(salvo.diaSemana, DateTime.monday);
    });

    testWidgets('editar um treino existente mantém dia/objetivo/vigência já preenchidos', (
      tester,
    ) async {
      final treinoExistente = Treino(
        id: 'treino-1',
        nome: 'Treino B',
        letra: 'B',
        diaSemana: 3,
        objetivo: 'Emagrecimento',
        vigenciaAte: DateTime(2026, 12, 31),
      );
      final alunoService = FakeAlunoService(treinos: [treinoExistente]);

      await tester.pumpWidget(
        _wrap(
          TreinoFormScreen(
            alunoUid: 'aluno-1',
            alunoService: alunoService,
            staffAtual: _staff,
            treino: treinoExistente,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Quarta'), findsOneWidget);
      expect(find.text('31/12/2026'), findsOneWidget);

      await _tocarSalvar(tester);
      await tester.pumpAndSettle();

      final salvo = alunoService.treinos.single;
      expect(salvo.diaSemana, 3);
      expect(salvo.objetivo, 'Emagrecimento');
      expect(salvo.vigenciaAte, DateTime(2026, 12, 31));
    });
  });
}
