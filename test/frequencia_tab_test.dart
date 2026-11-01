import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/evento_acesso.dart';
import 'package:gymextreme_app/models/historico_treino.dart';
import 'package:gymextreme_app/models/permission.dart';
import 'package:gymextreme_app/models/treino.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/tabs/frequencia_tab.dart';
import 'package:gymextreme_app/theme/app_theme.dart';

import 'support/fake_acesso_service.dart';
import 'support/fake_aluno_service.dart';

const _comControleCatraca = AppUser(
  uid: 'staff-com-catraca',
  nome: 'Staff Com Controle de Catraca',
  email: 'staff-catraca@teste.com',
  role: UserRole.funcionario,
  permissoes: {Permission.frequencia, Permission.controleCatraca},
);

const _semControleCatraca = AppUser(
  uid: 'staff-sem-catraca',
  nome: 'Staff Sem Controle de Catraca',
  email: 'staff-sem-catraca@teste.com',
  role: UserRole.funcionario,
  permissoes: {Permission.frequencia},
);

Widget _wrap(
  FakeAlunoService alunoService,
  FakeAcessoService acessoService, {
  AppUser staffAtual = _comControleCatraca,
}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: FrequenciaTab(
        uid: 'aluno-1',
        alunoService: alunoService,
        acessoService: acessoService,
        staffAtual: staffAtual,
      ),
    ),
  );
}

Future<void> _carregar(WidgetTester tester, Widget tela) async {
  await tester.pumpWidget(tela);
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('permissão controleCatraca — seção Acesso físico', () {
    testWidgets('staff SEM controleCatraca não vê a lista, só a mensagem de permissão', (
      tester,
    ) async {
      await _carregar(
        tester,
        _wrap(
          FakeAlunoService(),
          FakeAcessoService(
            eventos: [
              const EventoAcesso(id: 'evt-1', alunoUid: 'aluno-1', resultado: ResultadoAcesso.autorizado),
            ],
          ),
          staffAtual: _semControleCatraca,
        ),
      );

      expect(
        find.text('Você não tem permissão para ver o acesso físico deste aluno.'),
        findsOneWidget,
      );
      expect(find.text('Autorizado'), findsNothing);
    });

    testWidgets('staff COM controleCatraca vê os eventos de acesso do aluno', (tester) async {
      await _carregar(
        tester,
        _wrap(
          FakeAlunoService(),
          FakeAcessoService(
            eventos: [
              const EventoAcesso(
                id: 'evt-1',
                alunoUid: 'aluno-1',
                resultado: ResultadoAcesso.autorizado,
              ),
              const EventoAcesso(
                id: 'evt-2',
                alunoUid: 'aluno-1',
                resultado: ResultadoAcesso.negado,
                motivo: 'STUDENT_BLOCKED',
              ),
            ],
          ),
          staffAtual: _comControleCatraca,
        ),
      );

      expect(find.text('Autorizado'), findsOneWidget);
      expect(find.text('Negado'), findsOneWidget);
      expect(find.text('Acesso bloqueado'), findsOneWidget);
    });

    testWidgets('sem nenhum evento mostra o estado vazio, nunca a lista', (tester) async {
      await _carregar(
        tester,
        _wrap(FakeAlunoService(), FakeAcessoService(), staffAtual: _comControleCatraca),
      );

      expect(find.text('Nenhum registro de acesso físico ainda.'), findsOneWidget);
    });

    testWidgets('só mostra eventos do aluno certo (FakeAcessoService já filtra por alunoUid)', (
      tester,
    ) async {
      await _carregar(
        tester,
        _wrap(
          FakeAlunoService(),
          FakeAcessoService(
            eventos: [
              const EventoAcesso(
                id: 'evt-outro-aluno',
                alunoUid: 'aluno-outro',
                resultado: ResultadoAcesso.autorizado,
              ),
            ],
          ),
          staffAtual: _comControleCatraca,
        ),
      );

      expect(find.text('Nenhum registro de acesso físico ainda.'), findsOneWidget);
      expect(find.text('Autorizado'), findsNothing);
    });
  });

  group('presença de treino — Realizado / Falta / Não registrado', () {
    late DateTime hoje;

    setUp(() {
      final agora = DateTime.now();
      hoje = DateTime(agora.year, agora.month, agora.day);
    });

    Future<void> irParaAbaPresenca(WidgetTester tester) async {
      await tester.tap(find.text('Presença de treino'));
      await tester.pumpAndSettle();
    }

    testWidgets('dia com HistoricoTreino "realizado" aparece como Realizado', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: [Treino(id: 't1', nome: 'Peito e Tríceps', letra: 'A', diaSemana: hoje.weekday)],
        historicoTreinos: [
          HistoricoTreino(
            treinoId: 't1',
            data: hoje,
            diaSemana: hoje.weekday,
            status: StatusHistoricoTreino.realizado,
          ),
        ],
      );
      await _carregar(tester, _wrap(alunoService, FakeAcessoService()));
      await irParaAbaPresenca(tester);

      // A janela de 14 dias cobre o mesmo dia da semana duas vezes (hoje
      // e hoje-7) — só "hoje" tem HistoricoTreino, então a ocorrência de
      // 7 dias atrás aparece corretamente como "Não registrado" (nunca
      // "Falta"), não some da lista.
      expect(find.text('Realizado'), findsOneWidget);
      expect(find.text('Falta'), findsNothing);
      expect(find.text('Não registrado'), findsOneWidget);
    });

    testWidgets('dia com HistoricoTreino "falta" aparece como Falta', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: [Treino(id: 't1', nome: 'Pernas', letra: 'B', diaSemana: hoje.weekday)],
        historicoTreinos: [
          HistoricoTreino(
            treinoId: 't1',
            data: hoje,
            diaSemana: hoje.weekday,
            status: StatusHistoricoTreino.falta,
          ),
        ],
      );
      await _carregar(tester, _wrap(alunoService, FakeAcessoService()));
      await irParaAbaPresenca(tester);

      expect(find.text('Falta'), findsOneWidget);
      expect(find.text('Realizado'), findsNothing);
    });

    testWidgets(
      'dia com treino prescrito SEM HistoricoTreino aparece como "Não registrado", NUNCA "Falta"',
      (tester) async {
        final alunoService = FakeAlunoService(
          treinos: [Treino(id: 't1', nome: 'Costas', letra: 'C', diaSemana: hoje.weekday)],
          historicoTreinos: const [], // nenhum registro pra nenhum dia
        );
        await _carregar(tester, _wrap(alunoService, FakeAcessoService()));
        await irParaAbaPresenca(tester);

        // A janela de 14 dias cobre o mesmo dia da semana duas vezes
        // (hoje e hoje-7); sem NENHUM HistoricoTreino, as duas
        // ocorrências aparecem como "Não registrado".
        expect(find.text('Não registrado'), findsNWidgets(2));
        expect(find.text('Falta'), findsNothing);
      },
    );

    testWidgets('nenhum treino ativo com diaSemana definido mostra o estado vazio', (
      tester,
    ) async {
      final alunoService = FakeAlunoService(treinos: const [], historicoTreinos: const []);
      await _carregar(tester, _wrap(alunoService, FakeAcessoService()));
      await irParaAbaPresenca(tester);

      expect(
        find.text('Nenhum treino prescrito com dia da semana definido ainda.'),
        findsOneWidget,
      );
    });

    testWidgets('treino inativo (ativo: false) não gera linha nenhuma', (tester) async {
      final alunoService = FakeAlunoService(
        treinos: [
          Treino(id: 't1', nome: 'Antigo', letra: 'A', diaSemana: hoje.weekday, ativo: false),
        ],
        historicoTreinos: const [],
      );
      await _carregar(tester, _wrap(alunoService, FakeAcessoService()));
      await irParaAbaPresenca(tester);

      expect(
        find.text('Nenhum treino prescrito com dia da semana definido ainda.'),
        findsOneWidget,
      );
    });
  });
}
