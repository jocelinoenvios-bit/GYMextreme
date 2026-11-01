import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/utils/status_operacional_aluno.dart';

void main() {
  final hoje = DateTime(2026, 6, 15);

  group('calcularStatusOperacional', () {
    test('TESTE: mensalidade vence hoje → aluno continua ativo', () {
      final aluno = Aluno(uid: 'a1', proximoVencimento: hoje);
      expect(calcularStatusOperacional(aluno, hoje: hoje), StatusOperacionalAluno.ativo);
    });

    test('TESTE: sem nenhum vencimento configurado → ativo (nunca bloqueia por falta de dado)', () {
      const aluno = Aluno(uid: 'a1');
      expect(calcularStatusOperacional(aluno, hoje: hoje), StatusOperacionalAluno.ativo);
    });

    test('dentro dos dias de tolerância (7) → ainda não é inadimplente', () {
      final aluno = Aluno(uid: 'a1', proximoVencimento: hoje.subtract(const Duration(days: 6)));
      expect(calcularStatusOperacional(aluno, hoje: hoje), StatusOperacionalAluno.ativo);
    });

    test('TESTE: 15 dias de atraso → inadimplente (mensagem de retorno é disparada aqui)', () {
      final aluno = Aluno(uid: 'a1', proximoVencimento: hoje.subtract(const Duration(days: 15)));
      expect(calcularStatusOperacional(aluno, hoje: hoje), StatusOperacionalAluno.inadimplente);
    });

    test('TESTE: 30 dias de atraso mas Aluno.ativo ainda true (job não rodou hoje) → inadimplente', () {
      // calcularStatusOperacional só reflete o que já está gravado — quem
      // decide inativar de fato é a automação (ver functions/lib/inadimplencia.js).
      final aluno = Aluno(uid: 'a1', proximoVencimento: hoje.subtract(const Duration(days: 30)));
      expect(calcularStatusOperacional(aluno, hoje: hoje), StatusOperacionalAluno.inadimplente);
    });

    test('TESTE: Aluno.ativo == false → inativo, mesmo que a mensalidade pareça em dia', () {
      final aluno = Aluno(uid: 'a1', ativo: false, proximoVencimento: hoje);
      expect(calcularStatusOperacional(aluno, hoje: hoje), StatusOperacionalAluno.inativo);
    });
  });

  group('diasDesdeInativacao / aindaInativoDesde', () {
    test('aluno nunca inativado → null', () {
      const aluno = Aluno(uid: 'a1');
      expect(diasDesdeInativacao(aluno, hoje: hoje), isNull);
      expect(aindaInativoDesde(aluno), isFalse);
    });

    test('aluno inativo há 45 dias → conta certo', () {
      final aluno = Aluno(
        uid: 'a1',
        ativo: false,
        dataInativacao: hoje.subtract(const Duration(days: 45)),
      );
      expect(diasDesdeInativacao(aluno, hoje: hoje), 45);
      expect(aindaInativoDesde(aluno), isTrue);
    });

    test('aluno JÁ reativado (ativo=true) não conta mais dias, mesmo com dataInativacao antiga', () {
      final aluno = Aluno(
        uid: 'a1',
        ativo: true,
        dataInativacao: hoje.subtract(const Duration(days: 200)),
        dataReativacao: hoje.subtract(const Duration(days: 1)),
      );
      expect(diasDesdeInativacao(aluno, hoje: hoje), isNull);
      expect(aindaInativoDesde(aluno), isFalse);
    });
  });

  group('alunoPassaNoFiltro', () {
    test('FiltroStatusAluno.todos aceita qualquer aluno, inclusive sem ficha', () {
      expect(alunoPassaNoFiltro(null, FiltroStatusAluno.todos), isTrue);
    });

    test('sem ficha carregada ainda, nenhum filtro específico aceita', () {
      expect(alunoPassaNoFiltro(null, FiltroStatusAluno.ativos), isFalse);
      expect(alunoPassaNoFiltro(null, FiltroStatusAluno.inadimplentes), isFalse);
      expect(alunoPassaNoFiltro(null, FiltroStatusAluno.inativos), isFalse);
    });

    test('TESTE: 15+ dias de atraso aparece no filtro "15+ dias", não no "30 dias" (ainda ativo)', () {
      final aluno = Aluno(uid: 'a1', proximoVencimento: hoje.subtract(const Duration(days: 20)));
      expect(alunoPassaNoFiltro(aluno, FiltroStatusAluno.atraso15Dias, hoje: hoje), isTrue);
      expect(alunoPassaNoFiltro(aluno, FiltroStatusAluno.inativos, hoje: hoje), isFalse);
    });

    test('TESTE: aluno inativo há 45+ dias aparece nos filtros inativos e "45+ dias"', () {
      final aluno = Aluno(
        uid: 'a1',
        ativo: false,
        dataInativacao: hoje.subtract(const Duration(days: 50)),
      );
      expect(alunoPassaNoFiltro(aluno, FiltroStatusAluno.inativos, hoje: hoje), isTrue);
      expect(alunoPassaNoFiltro(aluno, FiltroStatusAluno.inatividade45Dias, hoje: hoje), isTrue);
    });

    test('aluno inativo há só 10 dias aparece em "inativos" mas não em "45+ dias"', () {
      final aluno = Aluno(
        uid: 'a1',
        ativo: false,
        dataInativacao: hoje.subtract(const Duration(days: 10)),
      );
      expect(alunoPassaNoFiltro(aluno, FiltroStatusAluno.inativos, hoje: hoje), isTrue);
      expect(alunoPassaNoFiltro(aluno, FiltroStatusAluno.inatividade45Dias, hoje: hoje), isFalse);
    });
  });
}
