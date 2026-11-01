import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/theme/app_theme.dart';
import 'package:gymextreme_app/widgets/premium.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('todo desenho dos ícones é um SVG que carrega', () async {
    // Um SVG malformado não quebra o build nem o analyze — só aparece
    // como erro em tempo de execução, no aparelho. Aqui cada desenho
    // passa pelo mesmo caminho de leitura que o app usa.
    for (final desenho in Desenhos.todos) {
      final bytes = await SvgStringLoader(
        IconePremium.svgDe(desenho),
      ).loadBytes(null);
      expect(bytes.lengthInBytes, greaterThan(0), reason: desenho.viewBox);
    }
  });

  group('CardPremium', () {
    testWidgets('mostra o rótulo e responde ao toque', (tester) async {
      var tocou = false;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 112,
            height: 112,
            child: CardPremium(
              desenho: Desenhos.painel,
              rotulo: 'Painel e relatórios',
              onTap: () => tocou = true,
            ),
          ),
        ),
      );

      expect(find.text('Painel e relatórios'), findsOneWidget);
      await tester.tap(find.byType(CardPremium));
      expect(tocou, isTrue);
    });

    testWidgets('selo de não lidas aparece com a contagem, e some no zero', (
      tester,
    ) async {
      Widget card(int naoLidas) => _wrap(
        SizedBox(
          width: 112,
          height: 112,
          child: CardPremium(
            desenho: Desenhos.mensagens,
            rotulo: 'Mensagens',
            naoLidas: naoLidas,
            onTap: () {},
          ),
        ),
      );

      await tester.pumpWidget(card(3));
      expect(find.text('3'), findsOneWidget);

      await tester.pumpWidget(card(12));
      expect(find.text('9+'), findsOneWidget);

      await tester.pumpWidget(card(0));
      expect(find.text('0'), findsNothing);
    });

    testWidgets('não estoura numa célula pequena, mesmo com fonte grande', (
      tester,
    ) async {
      // Já tivemos "BOTTOM OVERFLOWED" de verdade nos cards da tela
      // inicial — este é o caso que pegaria uma regressão disso.
      tester.platformDispatcher.textScaleFactorTestValue = 1.6;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 92,
            height: 90,
            child: CardPremium(
              desenho: Desenhos.biblioteca,
              rotulo: 'Biblioteca de exercícios',
              onTap: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('BotaoOuro mostra o rótulo e responde ao toque', (tester) async {
    var tocou = false;
    await tester.pumpWidget(
      _wrap(
        BotaoOuro(
          icone: Icons.fitness_center,
          rotulo: 'MEUS TREINOS',
          onTap: () => tocou = true,
        ),
      ),
    );

    await tester.tap(find.text('MEUS TREINOS'));
    expect(tocou, isTrue);
  });

  testWidgets('SaudacaoPremium junta "Bem-vindo," e o nome numa frase só', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const SaudacaoPremium(nome: 'ADM', nomeItalico: true)),
    );

    // Uma frase só pro leitor de tela, mesmo com o nome em outra cor.
    expect(find.text('Bem-vindo, ADM'), findsOneWidget);
  });
}
