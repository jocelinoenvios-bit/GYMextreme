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

  // Caminhos reais (existem de verdade em assets/exercicios/gifs/), não
  // fake — desde que a ficha do exercício passou a usar o widget `Gif`
  // (que, ao contrário do antigo `Image.asset`, não tem `errorBuilder`
  // e lança uma exceção real se o asset não existir), o teste que abre
  // a ficha (`ExercicioDetailScreen`) precisa de um caminho que o
  // asset bundle do Flutter realmente resolve.
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
      gif180Url: 'assets/exercicios/gifs/0001.gif',
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
      gif180Url: 'assets/exercicios/gifs/0577.gif',
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
    // Sem pumpAndSettle: o GIF do detalhe roda em loop infinito
    // (autostart automático), então nunca "assenta" — mesmo motivo de
    // exercicio_media_stage_test.dart usar só pump(). Duas bombeadas
    // bastam pra concluir a transição de rota (300ms padrão).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ExercicioDetailScreen), findsOneWidget);
  });

  testWidgets(
    'modo seletor devolve o ExerciseModel escolhido e fecha só a tela do seletor',
    (tester) async {
      ExerciseModel? selecionado;
      // Reproduz a pilha de navegação real (aluno detail -> TreinoFormScreen
      // -> seletor): uma tela "host" empurra o seletor por cima de si mesma,
      // e o onSelecionar fecha o seletor sozinho (Navigator.pop dentro do
      // próprio callback, igual TreinoFormScreen._adicionarExercicio) — sem
      // nenhum pop() extra dentro do ExerciciosListScreen. Antes da correção,
      // um pop() redundante ali fechava a tela host por baixo dele também
      // (o "Editar treino" sumia assim que um exercício era escolhido, antes
      // do usuário conseguir preencher os parâmetros e salvar).
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (rootContext) => ElevatedButton(
              onPressed: () => Navigator.of(rootContext).push(
                MaterialPageRoute(
                  builder: (hostContext) => Scaffold(
                    appBar: AppBar(title: const Text('Editar treino (host)')),
                    body: ElevatedButton(
                      onPressed: () => Navigator.of(hostContext).push(
                        MaterialPageRoute(
                          builder: (_) => ExerciciosListScreen(
                            repository: const _FakeExerciseRepository(),
                            onSelecionar: (e) {
                              selecionado = e;
                              Navigator.of(hostContext).pop(e);
                            },
                          ),
                        ),
                      ),
                      child: const Text('abrir seletor'),
                    ),
                  ),
                ),
              ),
              child: const Text('abrir host'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir host'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('abrir seletor'));
      await tester.pumpAndSettle();

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      await tester.tap(find.text('lever chest press'));
      await tester.pumpAndSettle();

      expect(selecionado?.id, '0577');
      // O ponto do teste: a tela host ("Editar treino") continua aberta —
      // só o seletor fechou.
      expect(find.text('Editar treino (host)'), findsOneWidget);
      expect(find.byType(ExerciciosListScreen), findsNothing);
    },
  );
}
