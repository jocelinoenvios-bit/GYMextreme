import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/theme/app_theme.dart';
import 'package:gymextreme_app/widgets/campo_forma_pagamento.dart';

Widget _tela(
  TextEditingController controller, {
  bool obrigatorio = false,
  GlobalKey<FormState>? form,
}) => MaterialApp(
  theme: AppTheme.dark,
  home: Scaffold(
    body: Form(
      key: form,
      child: CampoFormaPagamento(
        controller: controller,
        obrigatorio: obrigatorio,
      ),
    ),
  ),
);

void main() {
  testWidgets(
    'as 3 opções; escolher grava no controller; tocar de novo desmarca',
    (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_tela(controller));

      expect(find.text('Forma de pagamento (opcional)'), findsOneWidget);
      expect(find.text('Pix'), findsOneWidget);
      expect(find.text('Cartão'), findsOneWidget);
      expect(find.text('Dinheiro'), findsOneWidget);

      await tester.tap(find.text('Cartão'));
      await tester.pump();
      expect(controller.text, 'Cartão');

      await tester.tap(find.text('Dinheiro'));
      await tester.pump();
      expect(controller.text, 'Dinheiro');

      await tester.tap(find.text('Dinheiro'));
      await tester.pump();
      expect(controller.text, '');
    },
  );

  testWidgets('obrigatório: valida sem escolha e não desmarca', (tester) async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(_tela(controller, obrigatorio: true, form: form));

    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Escolha a forma de pagamento.'), findsOneWidget);

    await tester.tap(find.text('Pix'));
    await tester.pump();
    await tester.tap(find.text('Pix'));
    await tester.pump();
    expect(controller.text, 'Pix');
    expect(form.currentState!.validate(), isTrue);
  });

  testWidgets(
    'valor preenchido por fora aparece marcado (ex.: copiado da matrícula)',
    (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(_tela(controller));
      controller.text = 'Pix';
      await tester.pump();

      final semantica = tester.getSemantics(find.text('Pix'));
      expect(semantica.flagsCollection.isSelected, isTrue);
    },
  );

  testWidgets(
    'registro antigo digitado à mão vira um 4º botão marcado, sem se perder',
    (tester) async {
      final controller = TextEditingController(text: 'Transferência');
      await tester.pumpWidget(_tela(controller));

      expect(find.text('Transferência'), findsOneWidget);
      expect(controller.text, 'Transferência');
    },
  );
}
