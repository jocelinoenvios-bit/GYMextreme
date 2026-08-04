import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/exercise_model.dart';
import 'package:gymextreme_app/screens/exercicios/exercicio_detail_screen.dart';
import 'package:gymextreme_app/screens/exercicios/exercicios_list_screen.dart';
import 'package:gymextreme_app/services/exercise_repository.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.dark, home: child);

class _FakeExerciseRepository implements ExerciseRepository {
  const _FakeExerciseRepository();

  static const _catalogo = <ExerciseModel>[
    ExerciseModel(
      id: '0001',
      nome: '3/4 sit-up',
      bodyPart: 'waist',
      equipmentCategory: 'bodyweight',
      equipamentoTexto: 'body weight',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: 'sit up',
      gif180Url: 'assets/fake/0001.gif',
    ),
    ExerciseModel(
      id: '0577',
      nome: 'lever chest press',
      bodyPart: 'chest',
      equipmentCategory: 'machine',
      equipamentoTexto: 'leverage machine',
      dificuldade: 'beginner',
      categoria: 'strength',
      movementFamily: 'chest press',
      gif180Url: 'assets/fake/0577.gif',
    ),
  ];

  @override
  Future<ExerciseModel?> buscarPorId(String id) async {
    for (final exercicio in _catalogo) {
      if (exercicio.id == id) return exercicio;
    }
    return null;
  }

  @override
  Future<List<ExerciseModel>> buscarTodos() async => _catalogo;
}

Future<void> _carregar(WidgetTester tester, Widget tela) async {
  await tester.pumpWidget(_wrap(tela));
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('lista os exercicios da Biblioteca Oficial', (tester) async {
    await _carregar(tester, const ExerciciosListScreen(repository: _FakeExerciseRepository()));

    expect(find.text('3/4 sit-up'), findsOneWidget);
    expect(find.text('lever chest press'), findsOneWidget);
  });

  testWidgets('busca por nome filtra a lista', (tester) async {
    await _carregar(tester, const ExerciciosListScreen(repository: _FakeExerciseRepository()));

    await tester.enterText(find.byType(TextField), 'lever');
    await tester.pump();

    expect(find.text('lever chest press'), findsOneWidget);
    expect(find.text('3/4 sit-up'), findsNothing);
  });

  testWidgets('filtro por grupo muscular restringe a lista', (tester) async {
    await _carregar(tester, const ExerciciosListScreen(repository: _FakeExerciseRepository()));

    // 'Peito' aparece duas vezes (o chip de filtro e o subtítulo do
    // item "lever chest press") — mira especificamente no ChoiceChip.
    await tester.tap(find.widgetWithText(ChoiceChip, 'Peito'));
    await tester.pump();

    expect(find.text('lever chest press'), findsOneWidget);
    expect(find.text('3/4 sit-up'), findsNothing);
  });

  testWidgets('tocar num exercicio sem onSelecionar abre o detalhe', (tester) async {
    await _carregar(tester, const ExerciciosListScreen(repository: _FakeExerciseRepository()));

    await tester.tap(find.text('3/4 sit-up'));
    await tester.pumpAndSettle();

    expect(find.byType(ExercicioDetailScreen), findsOneWidget);
  });

  testWidgets('modo seletor devolve o ExerciseModel escolhido e fecha a tela', (tester) async {
    ExerciseModel? selecionado;
    // Empurra o seletor a partir de uma tela "host", igual ao uso real
    // (TreinoFormScreen empurra a lista) — o pop() do seletor precisa
    // de uma rota anterior pra voltar.
    await tester.pumpWidget(
      _wrap(
        Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExerciciosListScreen(
                  repository: const _FakeExerciseRepository(),
                  onSelecionar: (e) => selecionado = e,
                ),
              ),
            ),
            child: const Text('abrir seletor'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir seletor'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
    }

    await tester.tap(find.text('lever chest press'));
    await tester.pumpAndSettle();

    expect(selecionado?.id, '0577');
  });
}
