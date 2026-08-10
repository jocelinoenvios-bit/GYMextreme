import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/matricula.dart';
import 'package:gymextreme_app/screens/relatorios/relatorio_matriculas_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/test_viewport.dart';

Widget _wrap(FakeAlunoService service) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: RelatorioMatriculasScreen(alunoService: service),
  );
}

void main() {
  testWidgets('estado vazio mostra zeros e nao quebra', (tester) async {
    await tester.pumpWidget(_wrap(FakeAlunoService()));
    await tester.pumpAndSettle();

    expect(find.text('Relatório de matrículas'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
  });

  testWidgets('mostra matriculas ativa e cancelada com seus rotulos', (tester) async {
    usarViewportGrande(tester);
    final service = FakeAlunoService(
      matriculas: [
        Matricula(
          id: 'm1',
          alunoId: 'a1',
          planoId: 'p1',
          dataInicio: DateTime(2026, 1, 1),
          dataVencimento: DateTime(2026, 12, 1),
          valorContratado: 100,
        ),
        Matricula(
          id: 'm2',
          alunoId: 'a2',
          planoId: 'p1',
          dataInicio: DateTime(2025, 1, 1),
          dataVencimento: DateTime(2025, 12, 1),
          valorContratado: 100,
          status: StatusMatricula.cancelada,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    expect(find.text('Ativa'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('filtro de situacao esconde matriculas de outro status', (tester) async {
    usarViewportGrande(tester);
    final service = FakeAlunoService(
      matriculas: [
        Matricula(
          id: 'm1',
          alunoId: 'a1',
          planoId: 'p1',
          dataInicio: DateTime(2026, 1, 1),
          dataVencimento: DateTime(2026, 12, 1),
          valorContratado: 100,
        ),
        Matricula(
          id: 'm2',
          alunoId: 'a2',
          planoId: 'p1',
          dataInicio: DateTime(2025, 1, 1),
          dataVencimento: DateTime(2025, 12, 1),
          valorContratado: 100,
          status: StatusMatricula.cancelada,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<StatusMatricula?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelada').last);
    await tester.pumpAndSettle();

    // "Cancelada" aparece 2x: o valor selecionado no dropdown e a etiqueta
    // da matrícula listada.
    expect(find.text('Ativa'), findsNothing);
    expect(find.text('Cancelada'), findsNWidgets(2));
  });
}
