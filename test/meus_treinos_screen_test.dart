import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/treino.dart';
import 'package:gymextreme_app/screens/area_aluno/meus_treinos_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/treino_execucao_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

void main() {
  group('MeusTreinosScreen', () {
    testWidgets('sem nenhum treino ativo mostra o estado vazio', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: const [Treino(id: 'antigo', nome: 'Treino velho', letra: 'A', ativo: false)],
      );

      await tester.pumpWidget(_wrap(MeusTreinosScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('Nenhum treino prescrito ainda. Fale com seu personal.'), findsOneWidget);
    });

    testWidgets('lista só os treinos ativos, com letra/nome/grupo/quantidade de exercícios', (
      tester,
    ) async {
      final alunoService = FakeAlunoService(
        treinos: const [
          Treino(
            id: 'treino-a',
            nome: 'Treino A',
            letra: 'A',
            grupoMuscular: 'Peito e tríceps',
            exercicios: [
              TreinoExercicio(exercicioId: '0577', ordem: 0),
              TreinoExercicio(exercicioId: '0180', ordem: 1),
            ],
          ),
          Treino(id: 'inativo', nome: 'Treino antigo', letra: 'Z', ativo: false),
        ],
      );

      await tester.pumpWidget(_wrap(MeusTreinosScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('Treino A'), findsOneWidget);
      expect(find.text('Peito e tríceps • 2 exercício(s)'), findsOneWidget);
      expect(find.text('Treino antigo'), findsNothing);
    });

    testWidgets('tocar num treino abre a tela de execução', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: const [Treino(id: 'treino-a', nome: 'Treino A', letra: 'A')],
      );

      await tester.pumpWidget(_wrap(MeusTreinosScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      await tester.tap(find.text('Treino A'));
      await tester.pumpAndSettle();

      expect(find.byType(TreinoExecucaoScreen), findsOneWidget);
    });
  });
}
