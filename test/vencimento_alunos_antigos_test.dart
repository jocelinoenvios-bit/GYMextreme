import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/screens/alunos/alunos_list_screen.dart';
import 'package:gymextreme_app/screens/alunos/aviso_sem_vencimento.dart';
import 'package:gymextreme_app/theme/app_theme.dart';
import 'package:gymextreme_app/utils/mensalidade_utils.dart';

import 'support/fake_aluno_service.dart';
import 'support/fake_storage_service.dart';

AppUser _aluno(String uid, String nome, {DateTime? criadoEm}) => AppUser(
  uid: uid,
  nome: nome,
  email: '$uid@exemplo.com',
  role: UserRole.aluno,
  criadoEm: criadoEm,
);

const _adm = AppUser(
  uid: 'adm',
  nome: 'ADM',
  email: 'adm@exemplo.com',
  role: UserRole.adm,
);
// Personal legado: sem a permissão de receber mensalidades.
const _personal = AppUser(
  uid: 'p',
  nome: 'Personal',
  email: 'p@exemplo.com',
  role: UserRole.personal,
);

void main() {
  group('somarMeses', () {
    test('mesmo dia do mês, ou o último dia quando o mês é mais curto', () {
      expect(somarMeses(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(somarMeses(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
      expect(somarMeses(DateTime(2026, 11, 15), 3), DateTime(2027, 2, 15));
    });
  });

  group('vencimentoParaAlunoAntigo', () {
    final hoje = DateTime(2026, 11, 1, 15, 30);

    test('próxima vez que cai o dia em que começou, nunca no passado', () {
      expect(
        vencimentoParaAlunoAntigo(inicio: DateTime(2026, 8, 10), hoje: hoje),
        DateTime(2026, 11, 10),
      );
      expect(
        vencimentoParaAlunoAntigo(inicio: DateTime(2025, 3, 20), hoje: hoje),
        DateTime(2026, 11, 20),
      );
    });

    test('dia que já passou neste mês vai pro mês que vem', () {
      expect(
        vencimentoParaAlunoAntigo(inicio: DateTime(2026, 7, 1), hoje: hoje),
        DateTime(2026, 12, 1),
      );
      expect(
        vencimentoParaAlunoAntigo(
          inicio: DateTime(2026, 9, 5),
          hoje: DateTime(2026, 11, 20),
        ),
        DateTime(2026, 12, 5),
      );
    });

    test('dia 31 em mês curto cai no último dia', () {
      expect(
        vencimentoParaAlunoAntigo(
          inicio: DateTime(2026, 8, 31),
          hoje: DateTime(2027, 2, 2),
        ),
        DateTime(2027, 2, 28),
      );
    });

    test('começou há menos de um mês: 1 mês depois do início', () {
      expect(
        vencimentoParaAlunoAntigo(inicio: DateTime(2026, 10, 25), hoje: hoje),
        DateTime(2026, 11, 25),
      );
    });

    test('sem data de início: 1 mês a partir de hoje', () {
      expect(vencimentoParaAlunoAntigo(hoje: hoje), DateTime(2026, 12, 1));
    });
  });

  test(
    'alunosSemVencimento ignora quem já tem vencimento e quem está inativo',
    () {
      final hoje = DateTime(2026, 11, 1);
      final pendentes = alunosSemVencimento(
        alunos: [
          _aluno('a', 'Zé Sem Ficha', criadoEm: DateTime(2026, 9, 12)),
          _aluno('b', 'Ana Antiga'),
          _aluno('c', 'Caio Em Dia'),
          _aluno('d', 'Dora Inativa'),
        ],
        fichas: [
          Aluno(uid: 'b', dataInicio: DateTime(2026, 6, 3)),
          Aluno(uid: 'c', proximoVencimento: DateTime(2026, 11, 20)),
          const Aluno(uid: 'd', ativo: false),
        ],
        hoje: hoje,
      );

      expect(pendentes.map((p) => p.aluno.nome), [
        'Ana Antiga',
        'Zé Sem Ficha',
      ]);
      expect(pendentes[0].vencimento, DateTime(2026, 11, 3));
      // Sem ficha: usa a data de criação da conta.
      expect(pendentes[1].vencimento, DateTime(2026, 11, 12));
    },
  );

  Widget tela(FakeAlunoService service, AppUser staff) => MaterialApp(
    theme: AppTheme.dark,
    home: AlunosListScreen(
      alunoService: service,
      storageService: FakeStorageService(),
      staffAtual: staff,
    ),
  );

  testWidgets('tela Alunos: aviso, confirmação com as datas e preenchimento', (
    tester,
  ) async {
    final service = FakeAlunoService(
      alunos: [_aluno('b', 'Ana Antiga'), _aluno('c', 'Caio Em Dia')],
      fichasAlunos: [
        Aluno(uid: 'b', dataInicio: DateTime(2026, 6, 3)),
        Aluno(uid: 'c', proximoVencimento: DateTime(2030, 1, 1)),
      ],
    );
    await tester.pumpWidget(tela(service, _adm));
    await tester.pumpAndSettle();

    expect(find.text('1 aluno sem vencimento'), findsOneWidget);
    await tester.tap(find.text('PREENCHER'));
    await tester.pumpAndSettle();

    final esperado = vencimentoParaAlunoAntigo(
      inicio: DateTime(2026, 6, 3),
      hoje: DateTime.now(),
    );
    final data =
        '${esperado.day.toString().padLeft(2, '0')}/${esperado.month.toString().padLeft(2, '0')}/${esperado.year}';
    expect(find.text('Ana Antiga'), findsOneWidget);
    expect(find.text(data), findsOneWidget);
    expect(find.text('Caio Em Dia'), findsNothing);

    await tester.tap(find.text('PREENCHER').last);
    await tester.pumpAndSettle();

    expect(service.ultimoLoteVencimentos, {'b': esperado});
    expect(find.text('1 aluno sem vencimento'), findsNothing);
    expect(find.text('Vencimento preenchido para 1 aluno(s).'), findsOneWidget);
  });

  testWidgets('cancelar não grava nada', (tester) async {
    final service = FakeAlunoService(
      alunos: [_aluno('b', 'Ana Antiga')],
      fichasAlunos: [const Aluno(uid: 'b')],
    );
    await tester.pumpWidget(tela(service, _adm));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PREENCHER'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCELAR'));
    await tester.pumpAndSettle();

    expect(service.ultimoLoteVencimentos, isNull);
    expect(find.text('1 aluno sem vencimento'), findsOneWidget);
  });

  testWidgets('sem a permissão de receber mensalidades, o aviso não aparece', (
    tester,
  ) async {
    final service = FakeAlunoService(
      alunos: [_aluno('b', 'Ana Antiga')],
      fichasAlunos: [const Aluno(uid: 'b')],
    );
    await tester.pumpWidget(tela(service, _personal));
    await tester.pumpAndSettle();

    expect(find.byType(AvisoSemVencimento), findsNothing);
  });
}
