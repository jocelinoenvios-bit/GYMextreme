import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/historico_treino.dart';
import 'package:gymextreme_app/models/treino.dart';
import 'package:gymextreme_app/screens/area_aluno/historico_treinos_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

/// Segunda-feira (00:00) da semana atual, na mesma conta que a tela usa
/// internamente — sempre hoje ou uma data passada, nunca futura, então
/// serve como dia estável pros testes (não depende de que dia da semana
/// os testes rodam).
DateTime _segundaDaSemanaAtual() {
  final hoje = DateTime.now();
  final segundaAtual = hoje.subtract(Duration(days: hoje.weekday - 1));
  return DateTime(segundaAtual.year, segundaAtual.month, segundaAtual.day);
}

void main() {
  final segunda = _segundaDaSemanaAtual();

  group('HistoricoTreinosScreen — status por dia', () {
    testWidgets('dia com treino prescrito mas sem registro mostra "Não registrado", nunca "Falta"', (
      tester,
    ) async {
      final alunoService = FakeAlunoService(
        treinos: [const Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1)],
        historicoTreinos: const [],
      );

      await tester.pumpWidget(
        _wrap(HistoricoTreinosScreen(uid: 'aluno-1', alunoService: alunoService)),
      );
      await tester.pump();

      expect(find.text('Não registrado'), findsOneWidget);
      expect(find.text('Falta'), findsNothing);
    });

    testWidgets('registro de presença feito pelo staff mostra "Realizado"', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: [const Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1)],
        historicoTreinos: [
          HistoricoTreino(
            id: 'h1',
            treinoId: 'treino-a',
            data: segunda,
            diaSemana: 1,
            status: StatusHistoricoTreino.realizado,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(HistoricoTreinosScreen(uid: 'aluno-1', alunoService: alunoService)),
      );
      await tester.pump();

      expect(find.text('Realizado'), findsOneWidget);
      expect(find.text('Não registrado'), findsNothing);
    });

    testWidgets('registro de falta feito pelo staff mostra "Falta"', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: [const Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1)],
        historicoTreinos: [
          HistoricoTreino(
            id: 'h1',
            treinoId: 'treino-a',
            data: segunda,
            diaSemana: 1,
            status: StatusHistoricoTreino.falta,
          ),
        ],
      );

      await tester.pumpWidget(
        _wrap(HistoricoTreinosScreen(uid: 'aluno-1', alunoService: alunoService)),
      );
      await tester.pump();

      expect(find.text('Falta'), findsOneWidget);
    });

    testWidgets('dia sem nenhum treino prescrito mostra "Sem treino prescrito"', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: [const Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1)],
      );

      await tester.pumpWidget(
        _wrap(HistoricoTreinosScreen(uid: 'aluno-1', alunoService: alunoService)),
      );
      await tester.pump();

      expect(find.text('Sem treino prescrito'), findsWidgets);
    });

    testWidgets('sem nenhum treino com dia definido mostra o estado vazio', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: const [Treino(id: 'treino-a', nome: 'Treino A', letra: 'A')],
      );

      await tester.pumpWidget(
        _wrap(HistoricoTreinosScreen(uid: 'aluno-1', alunoService: alunoService)),
      );
      await tester.pump();

      expect(
        find.text(
          'Nenhum treino tem dia da semana definido ainda — '
          'fale com seu personal.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('não deixa navegar pra semanas futuras', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: [const Treino(id: 'treino-a', nome: 'Treino A', letra: 'A', diaSemana: 1)],
      );

      await tester.pumpWidget(
        _wrap(HistoricoTreinosScreen(uid: 'aluno-1', alunoService: alunoService)),
      );
      await tester.pump();

      final botaoProxima = find.widgetWithIcon(IconButton, Icons.chevron_right);
      final IconButton widget = tester.widget(botaoProxima);
      expect(widget.onPressed, isNull);
    });
  });
}
