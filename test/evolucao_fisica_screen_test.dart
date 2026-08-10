import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/avaliacao_fisica.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/relatorios/evolucao_fisica_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';

Widget _wrap(FakeAlunoService service) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: EvolucaoFisicaScreen(alunoService: service),
  );
}

void main() {
  testWidgets('sem aluno selecionado pede pra escolher um aluno', (tester) async {
    await tester.pumpWidget(_wrap(FakeAlunoService()));
    await tester.pumpAndSettle();

    expect(find.text('Selecione um aluno para ver a evolução física.'), findsOneWidget);
  });

  testWidgets('aluno sem avaliacoes mostra mensagem de historico vazio', (tester) async {
    final service = FakeAlunoService(
      alunos: [
        const AppUser(
          uid: 'a1',
          nome: 'Bia Ferreira',
          email: 'bia@exemplo.com',
          role: UserRole.aluno,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bia Ferreira').last);
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma avaliação física registrada para este aluno.'), findsOneWidget);
  });

  testWidgets('aluno com avaliacoes mostra peso, imc e medidas no historico', (tester) async {
    final service = FakeAlunoService(
      alunos: [
        const AppUser(
          uid: 'a1',
          nome: 'Bia Ferreira',
          email: 'bia@exemplo.com',
          role: UserRole.aluno,
        ),
      ],
      avaliacoes: [
        AvaliacaoFisica(
          id: 'av1',
          data: DateTime(2026, 7, 1),
          pesoKg: 70,
          alturaM: 1.70,
          circunferenciasCm: const {'cintura': 80},
        ),
        AvaliacaoFisica(
          id: 'av2',
          data: DateTime(2026, 8, 1),
          pesoKg: 68,
          alturaM: 1.70,
        ),
      ],
    );

    await tester.pumpWidget(_wrap(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bia Ferreira').last);
    await tester.pumpAndSettle();

    expect(find.text('Histórico'), findsOneWidget);
    expect(find.textContaining('Peso: 70.0 kg'), findsOneWidget);
    expect(find.textContaining('Peso: 68.0 kg'), findsOneWidget);
    expect(find.textContaining('Cintura'), findsOneWidget);
  });
}
