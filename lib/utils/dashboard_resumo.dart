import '../models/aluno.dart';
import '../models/app_user.dart';
import '../models/caixa.dart';
import '../models/caixa_movimentacao.dart';
import '../models/conta_pagar.dart';
import '../models/conta_receber.dart';
import '../models/matricula.dart';
import '../models/produto.dart';
import 'status_acesso.dart';
import 'status_conta_pagar.dart';
import 'status_conta_receber.dart';

/// Números resumidos do dashboard administrativo — tudo calculado a
/// partir de dados já carregados (nenhuma consulta ao Firestore aqui
/// dentro), pra ficar isolado e fácil de testar com listas soltas.
class DashboardResumo {
  const DashboardResumo({
    required this.totalAlunos,
    required this.alunosAtivos,
    required this.alunosBloqueados,
    required this.matriculasAtivas,
    required this.mensalidadesAReceber,
    required this.quantidadeMensalidadesAReceber,
    required this.contasAPagarEmAberto,
    required this.quantidadeContasAPagarEmAberto,
    required this.caixaAberto,
    required this.saldoEsperadoCaixa,
    required this.movimentacoesRecentes,
    required this.produtosEstoqueBaixo,
  });

  final int totalAlunos;
  final int alunosAtivos;
  final int alunosBloqueados;
  final int matriculasAtivas;

  /// Soma do valor líquido de todas as contas a receber ainda pendentes
  /// ou vencidas (nunca inclui pagas/canceladas).
  final double mensalidadesAReceber;
  final int quantidadeMensalidadesAReceber;

  /// Soma do valor final de todas as contas a pagar ainda pendentes ou
  /// vencidas.
  final double contasAPagarEmAberto;
  final int quantidadeContasAPagarEmAberto;

  /// `null` quando não há nenhum caixa aberto no momento.
  final Caixa? caixaAberto;

  /// Saldo inicial do caixa aberto + soma de todas as suas movimentações
  /// até agora. `null` sem caixa aberto (não faz sentido calcular).
  final double? saldoEsperadoCaixa;

  /// Últimas movimentações do caixa aberto (vazia se nenhum caixa aberto,
  /// ou se o caixa aberto ainda não tem nenhuma movimentação).
  final List<CaixaMovimentacao> movimentacoesRecentes;

  final int produtosEstoqueBaixo;
}

/// Calcula o resumo do dashboard a partir dos dados já carregados de cada
/// módulo — nenhuma leitura ao Firestore acontece aqui, só agregação pura.
///
/// [fichasAlunos] é a lista de `Aluno` (coleção `alunos`, um doc por uid)
/// usada para saber `proximoVencimento`/`ativo` de cada aluno — [alunos]
/// (lista de `AppUser`, coleção `usuarios` filtrada por `role == aluno`)
/// só tem identidade básica, sem essa informação.
DashboardResumo calcularResumoDashboard({
  required List<AppUser> alunos,
  required List<Aluno> fichasAlunos,
  required List<Matricula> matriculas,
  required List<ContaReceber> contasReceber,
  required List<ContaPagar> contasPagar,
  required List<Produto> produtos,
  Caixa? caixaAberto,
  List<CaixaMovimentacao> movimentacoesCaixaAberto = const [],
  DateTime? hoje,
}) {
  final fichasPorUid = {for (final ficha in fichasAlunos) ficha.uid: ficha};

  var ativos = 0;
  var bloqueados = 0;
  for (final aluno in alunos) {
    final ficha = fichasPorUid[aluno.uid];
    final status = calcularStatusAcesso(
      proximoVencimento: ficha?.proximoVencimento,
      hoje: hoje,
    );
    if (status.status == StatusMensalidade.bloqueado) {
      bloqueados++;
    } else if (ficha?.ativo ?? true) {
      ativos++;
    }
  }

  final matriculasAtivas = matriculas
      .where((m) => m.status == StatusMatricula.ativa)
      .length;

  final contasReceberEmAberto = contasReceber.where((c) {
    final statusEfetivo = calcularStatusEfetivo(c, hoje: hoje);
    return statusEfetivo == StatusContaReceber.pendente ||
        statusEfetivo == StatusContaReceber.vencido;
  }).toList();
  final mensalidadesAReceber = contasReceberEmAberto.fold<double>(
    0,
    (soma, c) => soma + c.saldoDevedor,
  );

  final contasPagarEmAberto = contasPagar.where((c) {
    final statusEfetivo = calcularStatusEfetivoContaPagar(c, hoje: hoje);
    return statusEfetivo == StatusContaPagar.pendente ||
        statusEfetivo == StatusContaPagar.vencido;
  }).toList();
  final totalContasAPagar = contasPagarEmAberto.fold<double>(
    0,
    (soma, c) => soma + c.saldoAPagar,
  );

  double? saldoEsperadoCaixa;
  if (caixaAberto != null) {
    saldoEsperadoCaixa =
        caixaAberto.valorInicial +
        movimentacoesCaixaAberto.fold<double>(0, (soma, m) => soma + m.valor);
  }

  final produtosEstoqueBaixo = produtos
      .where((p) => p.ativo && p.estoqueBaixo)
      .length;

  return DashboardResumo(
    totalAlunos: alunos.length,
    alunosAtivos: ativos,
    alunosBloqueados: bloqueados,
    matriculasAtivas: matriculasAtivas,
    mensalidadesAReceber: mensalidadesAReceber,
    quantidadeMensalidadesAReceber: contasReceberEmAberto.length,
    contasAPagarEmAberto: totalContasAPagar,
    quantidadeContasAPagarEmAberto: contasPagarEmAberto.length,
    caixaAberto: caixaAberto,
    saldoEsperadoCaixa: saldoEsperadoCaixa,
    movimentacoesRecentes: movimentacoesCaixaAberto,
    produtosEstoqueBaixo: produtosEstoqueBaixo,
  );
}
