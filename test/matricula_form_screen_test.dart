import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/matricula.dart';
import 'package:gymextreme_app/models/plano.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/matriculas/matricula_form_screen.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_plano_service.dart';

const _carlos = AppUser(
  uid: 'aluno-carlos',
  nome: 'Carlos Souza',
  email: 'carlos@exemplo.com',
  role: UserRole.aluno,
);

const _planoMensal = Plano(id: 'plano-mensal', nome: 'Mensal', valor: 129.9, duracaoDias: 30);

// O formulário tem mais campos do que cabem no viewport padrão de teste —
// sem rolar até o botão primeiro, tap() acerta um ponto fora da tela.
Future<void> _tocar(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pump();
  await tester.tap(finder);
}

Widget _wrap(
  FakeAlunoService alunoService,
  FakePlanoService planoService, {
  AppUser? alunoPreSelecionado,
  Plano? planoPreSelecionado,
  double? valorPreSelecionado,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: MatriculaFormScreen(
      alunoService: alunoService,
      planoService: planoService,
      alunoPreSelecionado: alunoPreSelecionado,
      planoPreSelecionado: planoPreSelecionado,
      valorPreSelecionado: valorPreSelecionado,
    ),
  );
}

void main() {
  testWidgets('cria matricula nova escolhendo aluno e plano', (tester) async {
    final alunoService = FakeAlunoService(alunos: const [_carlos]);
    final planoService = FakePlanoService(planos: const [_planoMensal]);

    await tester.pumpWidget(_wrap(alunoService, planoService));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DropdownButtonFormField<AppUser>, 'Aluno'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Carlos Souza').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(DropdownButtonFormField<Plano>, 'Plano'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mensal').last);
    await tester.pumpAndSettle();

    // Valor ja vem preenchido a partir do plano selecionado.
    expect(find.text('129,90'), findsOneWidget);

    await _tocar(tester, find.text('CRIAR MATRÍCULA'));
    await tester.pump();

    final matricula = alunoService.matriculas.single;
    expect(matricula.alunoId, _carlos.uid);
    expect(matricula.planoId, _planoMensal.id);
    expect(matricula.valorContratado, 129.9);
    expect(matricula.dataVencimento.difference(matricula.dataInicio).inDays, 30);
  });

  testWidgets('nao salva sem selecionar aluno e plano', (tester) async {
    final alunoService = FakeAlunoService();
    final planoService = FakePlanoService();

    await tester.pumpWidget(_wrap(alunoService, planoService));
    await tester.pumpAndSettle();

    await _tocar(tester, find.text('CRIAR MATRÍCULA'));
    await tester.pump();

    // Sem plano selecionado o campo "Valor" também fica vazio, então a
    // validação do formulário já barra o envio antes mesmo de checar
    // aluno/plano — o que importa aqui é que nada foi salvo.
    expect(alunoService.matriculas, isEmpty);
  });

  testWidgets('fluxo de renovacao pre-preenche aluno e plano e nao mostra dropdown de aluno', (
    tester,
  ) async {
    final alunoService = FakeAlunoService(
      alunos: const [_carlos],
      matriculas: [
        Matricula(
          id: 'm1',
          alunoId: _carlos.uid,
          planoId: _planoMensal.id!,
          dataInicio: DateTime(2026, 7, 1),
          dataVencimento: DateTime(2026, 8, 1),
          valorContratado: 129.9,
          status: StatusMatricula.vencida,
        ),
      ],
    );
    final planoService = FakePlanoService(planos: const [_planoMensal]);

    await tester.pumpWidget(
      _wrap(
        alunoService,
        planoService,
        alunoPreSelecionado: _carlos,
        planoPreSelecionado: _planoMensal,
        valorPreSelecionado: 129.9,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Renovar matrícula'), findsOneWidget);
    expect(find.text('Carlos Souza'), findsOneWidget);
    expect(find.byType(DropdownButtonFormField<AppUser>), findsNothing);

    await _tocar(tester, find.text('CONFIRMAR RENOVAÇÃO'));
    await tester.pump();

    // A matricula vencida antiga continua no historico; a nova entra
    // como ativa por cima dela.
    expect(alunoService.matriculas, hasLength(2));
    expect(
      alunoService.matriculas.where((m) => m.status == StatusMatricula.ativa),
      hasLength(1),
    );
  });
}
