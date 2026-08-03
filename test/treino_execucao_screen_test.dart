import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/screens/area_aluno/treino_execucao_screen.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

/// Repositório de teste — a correção da Biblioteca Oficial em si (todos
/// os 1.394 exercícios, relacionamentos, taxonomy) já é validada contra
/// o asset real em `exercise_repository_test.dart`. Esta tela só precisa
/// validar comportamento de UI (carregamento, progressão de séries,
/// descanso, conclusão), então usa dados fixos e resolução imediata —
/// sem depender de `compute()`/isolate de verdade dentro da fake-async
/// zone do `testWidgets`, que se mostrou não confiável mesmo com
/// pré-aquecimento do cache estático.
class _FakeExerciseRepository implements ExerciseRepository {
  const _FakeExerciseRepository();

  static const _catalogo = <String, ExerciseModel>{
    '0577': ExerciseModel(
      id: '0577',
      nome: 'lever chest press',
      bodyPart: 'chest',
      equipmentCategory: 'machine',
      equipamentoTexto: 'leverage machine',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: 'chest press',
      musculosPrincipais: ['chest'],
      gif180Url: 'assets/exercicios/gifs/0577.gif',
    ),
    '0180': ExerciseModel(
      id: '0180',
      nome: 'cable seated row',
      bodyPart: 'back',
      equipmentCategory: 'cable',
      equipamentoTexto: 'cable',
      dificuldade: 'intermediate',
      categoria: 'strength',
      movementFamily: 'row',
      musculosPrincipais: ['back'],
      gif180Url: 'assets/exercicios/gifs/0180.gif',
    ),
    '0043': ExerciseModel(
      id: '0043',
      nome: 'barbell full squat',
      bodyPart: 'upper legs',
      equipmentCategory: 'free_weight',
      equipamentoTexto: 'barbell',
      dificuldade: 'advanced',
      categoria: 'strength',
      movementFamily: 'squat',
      musculosPrincipais: ['quads'],
      gif180Url: 'assets/exercicios/gifs/0043.gif',
    ),
  };

  @override
  Future<ExerciseModel?> buscarPorId(String id) async => _catalogo[id];

  @override
  Future<List<ExerciseModel>> buscarTodos() async => _catalogo.values.toList(growable: false);
}

const _tela = TreinoExecucaoScreen(
  treinoId: 'preview-mock',
  treinoNome: 'Treino B',
  repository: _FakeExerciseRepository(),
);

/// Nunca usar pumpAndSettle() aqui, porque o pulso da demonstração
/// (AnimationController em loop infinito) nunca "assenta". Espera em
/// passos curtos até o spinner de carregamento sumir, com um teto de
/// tentativas — o fake repository resolve em poucos microtasks.
Future<void> _carregar(WidgetTester tester) async {
  await tester.pumpWidget(_wrap(_tela));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('carrega da Biblioteca Oficial e mostra o primeiro exercicio prescrito', (
    tester,
  ) async {
    await _carregar(tester);

    expect(find.text('lever chest press'), findsWidgets);
    expect(find.text('CONCLUIR SÉRIE 1'), findsOneWidget);
    expect(find.text('Exercício 1 de 3'), findsOneWidget);
  });

  testWidgets('concluir uma serie nao-final entra em descanso; pular volta pronto pra proxima', (
    tester,
  ) async {
    await _carregar(tester);

    await tester.tap(find.text('CONCLUIR SÉRIE 1'));
    await tester.pump();
    expect(find.text('PULAR DESCANSO'), findsOneWidget);
    expect(find.text('CONCLUIR SÉRIE 1'), findsNothing);

    await tester.tap(find.text('PULAR DESCANSO'));
    await tester.pump();
    expect(find.text('CONCLUIR SÉRIE 2'), findsOneWidget);
  });

  testWidgets('concluir a ultima serie do ultimo exercicio mostra a tela de conclusao', (
    tester,
  ) async {
    await _carregar(tester);

    for (var i = 0; i < 20; i++) {
      if (find.text('Treino concluído!').evaluate().isNotEmpty) break;

      final pularDescanso = find.text('PULAR DESCANSO');
      if (pularDescanso.evaluate().isNotEmpty) {
        await tester.tap(pularDescanso);
        await tester.pump();
        continue;
      }

      final botaoConcluir = find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data ?? '').startsWith('CONCLUIR SÉRIE'),
      );
      expect(botaoConcluir, findsOneWidget, reason: 'esperava um botão de concluir série ainda visível');
      await tester.tap(botaoConcluir);
      await tester.pump();
    }

    expect(find.text('Treino concluído!'), findsOneWidget);
    expect(find.text('3 exercícios finalizados'), findsOneWidget);
  });
}
