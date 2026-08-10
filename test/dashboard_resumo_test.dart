import 'package:flutter_test/flutter_test.dart';
import 'package:gymextreme_app/models/aluno.dart';
import 'package:gymextreme_app/models/app_user.dart';
import 'package:gymextreme_app/models/caixa.dart';
import 'package:gymextreme_app/models/caixa_movimentacao.dart';
import 'package:gymextreme_app/models/conta_pagar.dart';
import 'package:gymextreme_app/models/conta_receber.dart';
import 'package:gymextreme_app/models/matricula.dart';
import 'package:gymextreme_app/models/produto.dart';
import 'package:gymextreme_app/models/user_role.dart';
import 'package:gymextreme_app/utils/dashboard_resumo.dart';

final _hoje = DateTime(2026, 8, 10);

AppUser _aluno(String uid) =>
    AppUser(uid: uid, nome: 'Aluno $uid', email: '$uid@x.com', role: UserRole.aluno);

void main() {
  group('calcularResumoDashboard — estado vazio', () {
    test('tudo zerado/vazio quando nao ha nenhum dado', () {
      final resumo = calcularResumoDashboard(
        alunos: const [],
        fichasAlunos: const [],
        matriculas: const [],
        contasReceber: const [],
        contasPagar: const [],
        produtos: const [],
        hoje: _hoje,
      );

      expect(resumo.totalAlunos, 0);
      expect(resumo.alunosAtivos, 0);
      expect(resumo.alunosBloqueados, 0);
      expect(resumo.matriculasAtivas, 0);
      expect(resumo.mensalidadesAReceber, 0);
      expect(resumo.contasAPagarEmAberto, 0);
      expect(resumo.caixaAberto, isNull);
      expect(resumo.saldoEsperadoCaixa, isNull);
      expect(resumo.movimentacoesRecentes, isEmpty);
      expect(resumo.produtosEstoqueBaixo, 0);
    });
  });

  group('calcularResumoDashboard — alunos ativos/bloqueados', () {
    test('separa alunos ativos de bloqueados a partir da ficha (proximoVencimento)', () {
      final resumo = calcularResumoDashboard(
        alunos: [_aluno('a1'), _aluno('a2'), _aluno('a3')],
        fichasAlunos: [
          Aluno(uid: 'a1', proximoVencimento: DateTime(2026, 12, 1)), // em dia
          Aluno(uid: 'a2', proximoVencimento: DateTime(2020, 1, 1)), // bloqueado
          // a3 sem ficha: semRegistro, conta como ativo (nunca bloqueia)
        ],
        matriculas: const [],
        contasReceber: const [],
        contasPagar: const [],
        produtos: const [],
        hoje: _hoje,
      );

      expect(resumo.totalAlunos, 3);
      expect(resumo.alunosBloqueados, 1);
      expect(resumo.alunosAtivos, 2);
    });

    test('aluno com ficha ativo=false nao conta como ativo mesmo em dia', () {
      final resumo = calcularResumoDashboard(
        alunos: [_aluno('a1')],
        fichasAlunos: [
          Aluno(uid: 'a1', proximoVencimento: DateTime(2026, 12, 1), ativo: false),
        ],
        matriculas: const [],
        contasReceber: const [],
        contasPagar: const [],
        produtos: const [],
        hoje: _hoje,
      );

      expect(resumo.alunosAtivos, 0);
      expect(resumo.alunosBloqueados, 0);
    });
  });

  test('conta matriculas ativas, ignorando as demais', () {
    final resumo = calcularResumoDashboard(
      alunos: const [],
      fichasAlunos: const [],
      matriculas: [
        Matricula(
          alunoId: 'a1',
          planoId: 'p1',
          dataInicio: DateTime(2026, 1, 1),
          dataVencimento: DateTime(2026, 12, 1),
          valorContratado: 100,
        ),
        Matricula(
          alunoId: 'a2',
          planoId: 'p1',
          dataInicio: DateTime(2026, 1, 1),
          dataVencimento: DateTime(2026, 2, 1),
          valorContratado: 100,
          status: StatusMatricula.vencida,
        ),
      ],
      contasReceber: const [],
      contasPagar: const [],
      produtos: const [],
      hoje: _hoje,
    );

    expect(resumo.matriculasAtivas, 1);
  });

  test('soma mensalidades a receber (pendente + vencido), ignora pago/cancelado', () {
    final resumo = calcularResumoDashboard(
      alunos: const [],
      fichasAlunos: const [],
      matriculas: const [],
      contasReceber: [
        ContaReceber(
          alunoId: 'a1',
          descricao: 'Pendente',
          valorOriginal: 100,
          vencimento: DateTime(2026, 12, 1),
        ),
        ContaReceber(
          alunoId: 'a1',
          descricao: 'Vencida',
          valorOriginal: 50,
          vencimento: DateTime(2020, 1, 1),
        ),
        ContaReceber(
          alunoId: 'a1',
          descricao: 'Paga',
          valorOriginal: 200,
          valorPago: 200,
          vencimento: DateTime(2026, 1, 1),
          status: StatusContaReceber.pago,
        ),
      ],
      contasPagar: const [],
      produtos: const [],
      hoje: _hoje,
    );

    expect(resumo.mensalidadesAReceber, 150);
    expect(resumo.quantidadeMensalidadesAReceber, 2);
  });

  test('soma contas a pagar em aberto (pendente + vencido), ignora pago/cancelado', () {
    final resumo = calcularResumoDashboard(
      alunos: const [],
      fichasAlunos: const [],
      matriculas: const [],
      contasReceber: const [],
      contasPagar: [
        ContaPagar(
          fornecedor: 'F1',
          descricao: 'Aluguel',
          categoria: 'Aluguel',
          valorOriginal: 1000,
          vencimento: DateTime(2026, 12, 1),
        ),
        ContaPagar(
          fornecedor: 'F2',
          descricao: 'Luz',
          categoria: 'Utilidades',
          valorOriginal: 300,
          vencimento: DateTime(2020, 1, 1),
        ),
      ],
      produtos: const [],
      hoje: _hoje,
    );

    expect(resumo.contasAPagarEmAberto, 1300);
    expect(resumo.quantidadeContasAPagarEmAberto, 2);
  });

  group('calcularResumoDashboard — caixa', () {
    test('sem caixa aberto, saldo esperado e nulo', () {
      final resumo = calcularResumoDashboard(
        alunos: const [],
        fichasAlunos: const [],
        matriculas: const [],
        contasReceber: const [],
        contasPagar: const [],
        produtos: const [],
        hoje: _hoje,
      );

      expect(resumo.caixaAberto, isNull);
      expect(resumo.saldoEsperadoCaixa, isNull);
    });

    test('com caixa aberto, saldo esperado soma valor inicial + movimentacoes', () {
      final caixa = Caixa(
        id: 'c1',
        valorInicial: 100,
        abertoPorUid: 's1',
        abertoPorNome: 'Ana',
        abertoEm: _hoje,
      );
      final resumo = calcularResumoDashboard(
        alunos: const [],
        fichasAlunos: const [],
        matriculas: const [],
        contasReceber: const [],
        contasPagar: const [],
        produtos: const [],
        caixaAberto: caixa,
        movimentacoesCaixaAberto: const [
          CaixaMovimentacao(
            tipo: TipoMovimentacaoCaixa.suprimento,
            valor: 50,
            staffUid: 's1',
            staffNome: 'Ana',
          ),
          CaixaMovimentacao(
            tipo: TipoMovimentacaoCaixa.retirada,
            valor: -20,
            staffUid: 's1',
            staffNome: 'Ana',
          ),
        ],
        hoje: _hoje,
      );

      expect(resumo.caixaAberto, caixa);
      expect(resumo.saldoEsperadoCaixa, 130);
      expect(resumo.movimentacoesRecentes, hasLength(2));
    });
  });

  test('conta produtos ativos com estoque baixo, ignora inativos', () {
    final resumo = calcularResumoDashboard(
      alunos: const [],
      fichasAlunos: const [],
      matriculas: const [],
      contasReceber: const [],
      contasPagar: const [],
      produtos: const [
        Produto(
          nome: 'P1',
          codigo: 'C1',
          categoria: 'Cat',
          unidadeMedida: 'un',
          precoCusto: 10,
          precoVenda: 20,
          estoqueAtual: 1,
          estoqueMinimo: 5,
        ),
        Produto(
          nome: 'P2',
          codigo: 'C2',
          categoria: 'Cat',
          unidadeMedida: 'un',
          precoCusto: 10,
          precoVenda: 20,
          estoqueAtual: 20,
          estoqueMinimo: 5,
        ),
        Produto(
          nome: 'P3 inativo',
          codigo: 'C3',
          categoria: 'Cat',
          unidadeMedida: 'un',
          precoCusto: 10,
          precoVenda: 20,
          estoqueAtual: 0,
          estoqueMinimo: 5,
          ativo: false,
        ),
      ],
      hoje: _hoje,
    );

    expect(resumo.produtosEstoqueBaixo, 1);
  });
}
