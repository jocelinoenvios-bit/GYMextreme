import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/plano.dart';
import 'package:gymextreme_app/screens/planos/plano_form_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_plano_service.dart';

Widget _wrap(FakePlanoService service, {Plano? plano}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: PlanoFormScreen(planoService: service, plano: plano),
  );
}

void main() {
  testWidgets('nao salva com nome, valor ou duracao vazios', (tester) async {
    final service = FakePlanoService();
    await tester.pumpWidget(_wrap(service));

    await tester.tap(find.text('CADASTRAR PLANO'));
    await tester.pump();

    expect(find.text('Informe o nome.'), findsOneWidget);
    expect(service.ultimoPlanoSalvo, isNull);
  });

  testWidgets('cadastra um plano novo com dados validos', (tester) async {
    final service = FakePlanoService();
    await tester.pumpWidget(_wrap(service));

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'), 'Mensal');
    await tester.enterText(find.widgetWithText(TextFormField, 'Valor (R\$)'), '129,90');
    await tester.enterText(find.widgetWithText(TextFormField, 'Duração (dias)'), '30');

    await tester.tap(find.text('CADASTRAR PLANO'));
    await tester.pump();

    expect(service.ultimoPlanoSalvo, isNotNull);
    expect(service.ultimoPlanoSalvo!.nome, 'Mensal');
    expect(service.ultimoPlanoSalvo!.valor, 129.9);
    expect(service.ultimoPlanoSalvo!.duracaoDias, 30);
  });

  testWidgets('modo edicao pre-preenche os campos e permite desativar', (tester) async {
    final service = FakePlanoService();
    const plano = Plano(id: 'p1', nome: 'Trimestral', valor: 349, duracaoDias: 90);
    await tester.pumpWidget(_wrap(service, plano: plano));

    expect(find.text('Editar plano'), findsOneWidget);
    expect(find.text('Trimestral'), findsOneWidget);
    expect(find.text('Plano ativo'), findsOneWidget);

    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('SALVAR ALTERAÇÕES'));
    await tester.pump();

    expect(service.ultimoPlanoSalvo!.id, 'p1');
    expect(service.ultimoPlanoSalvo!.ativo, isFalse);
  });
}
