import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/treino.dart';
import 'package:gymextreme_app/screens/area_aluno/historico_treinos_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/minha_ficha_screen.dart';
import 'package:gymextreme_app/screens/area_aluno/treino_detalhe_aluno_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

void main() {
  group('MinhaFichaScreen', () {
    testWidgets('sem nenhum treino ativo mostra o estado vazio', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: const [Treino(id: 'antigo', nome: 'Treino velho', letra: 'A', ativo: false)],
      );

      await tester.pumpWidget(_wrap(MinhaFichaScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('Você ainda não possui uma ficha de treino cadastrada.'), findsOneWidget);
    });

    testWidgets('agrupa os treinos ativos pelo dia da semana prescrito', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: const [
          Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1),
          Treino(id: 'treino-b', nome: 'Treino B', letra: 'B', diaSemana: 3),
        ],
      );

      await tester.pumpWidget(_wrap(MinhaFichaScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('SEGUNDA'), findsOneWidget);
      expect(find.text('QUARTA'), findsOneWidget);
      expect(find.text('Treino A'), findsOneWidget);
      expect(find.text('Treino B'), findsOneWidget);
    });

    testWidgets('treino sem dia definido aparece numa seção própria, nunca escondido', (
      tester,
    ) async {
      final alunoService = FakeAlunoService(
        treinos: const [Treino(id: 'treino-c', nome: 'Treino C', letra: 'C')],
      );

      await tester.pumpWidget(_wrap(MinhaFichaScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('SEM DIA DEFINIDO'), findsOneWidget);
      expect(find.text('Treino C'), findsOneWidget);
    });

    testWidgets('a ficha prescrita continua visível mesmo sem nenhum histórico de presença', (
      tester,
    ) async {
      // Sem `historicoTreinos` nenhum (nenhuma falta/presença registrada
      // ainda) — a ficha nunca deve depender disso pra aparecer.
      final alunoService = FakeAlunoService(
        treinos: const [Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 2)],
        historicoTreinos: const [],
      );

      await tester.pumpWidget(_wrap(MinhaFichaScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      expect(find.text('Treino A'), findsOneWidget);
    });

    testWidgets('tocar num treino abre a ficha detalhada', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: const [Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1)],
      );

      await tester.pumpWidget(_wrap(MinhaFichaScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      await tester.tap(find.text('Treino A'));
      await tester.pumpAndSettle();

      expect(find.byType(TreinoDetalheAlunoScreen), findsOneWidget);
    });

    testWidgets('botão de histórico abre a tela de histórico de treinos', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: const [Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1)],
      );

      await tester.pumpWidget(_wrap(MinhaFichaScreen(uid: 'aluno-1', alunoService: alunoService)));
      await tester.pump();

      await tester.tap(find.text('HISTÓRICO DE TREINOS (SEMANAS ANTERIORES)'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoricoTreinosScreen), findsOneWidget);
    });
  });
}
