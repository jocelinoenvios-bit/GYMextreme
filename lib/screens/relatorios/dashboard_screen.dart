import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/caixa.dart';
import '../../models/caixa_movimentacao.dart';
import '../../services/aluno_service.dart';
import '../../services/caixa_service.dart';
import '../../services/conta_pagar_service.dart';
import '../../services/produto_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/dashboard_resumo.dart';
import '../../utils/moeda.dart';
import 'evolucao_fisica_screen.dart';
import 'relatorio_alunos_screen.dart';
import 'relatorio_estoque_screen.dart';
import 'relatorio_financeiro_screen.dart';
import 'relatorio_matriculas_screen.dart';

/// Dashboard administrativo — números resumidos de todos os módulos já
/// existentes (alunos, matrículas, financeiro, caixa, estoque) numa tela
/// só, mais um ponto de entrada pra cada relatório detalhado.
///
/// Carrega os dados com leituras únicas (`Future.wait` sobre `.first` de
/// cada stream), não com listeners permanentes — um dashboard não precisa
/// se atualizar sozinho a cada escrita no banco; "Atualizar" refaz a
/// carga sob demanda.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.alunoService,
    required this.caixaService,
    required this.contaPagarService,
    required this.produtoService,
    required this.staffAtual,
  });

  final AlunoService alunoService;
  final CaixaService caixaService;
  final ContaPagarService contaPagarService;
  final ProdutoService produtoService;
  final AppUser staffAtual;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardResumo> _resumoFuture;

  @override
  void initState() {
    super.initState();
    _resumoFuture = _carregarResumo();
  }

  Future<DashboardResumo> _carregarResumo() async {
    final alunos = widget.alunoService.watchAlunos().first;
    final fichasAlunos = widget.alunoService.watchTodosAlunos().first;
    final matriculas = widget.alunoService.watchTodasMatriculas().first;
    final contasReceber = widget.alunoService.watchTodasContasReceber().first;
    final contasPagar = widget.contaPagarService.watchContasPagar().first;
    final produtos = widget.produtoService.watchProdutos().first;
    final caixaAberto = widget.caixaService.watchCaixaAberto().first;

    final resultados = await (
      alunos,
      fichasAlunos,
      matriculas,
      contasReceber,
      contasPagar,
      produtos,
      caixaAberto,
    ).wait;

    final Caixa? caixa = resultados.$7;
    final List<CaixaMovimentacao> movimentacoesCaixa = caixa == null
        ? const []
        : await widget.caixaService.watchMovimentacoes(caixa.id!).first;

    return calcularResumoDashboard(
      alunos: resultados.$1,
      fichasAlunos: resultados.$2,
      matriculas: resultados.$3,
      contasReceber: resultados.$4,
      contasPagar: resultados.$5,
      produtos: resultados.$6,
      caixaAberto: caixa,
      movimentacoesCaixaAberto: movimentacoesCaixa,
    );
  }

  void _atualizar() {
    setState(() {
      _resumoFuture = _carregarResumo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel administrativo'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _atualizar,
          ),
        ],
      ),
      body: FutureBuilder<DashboardResumo>(
        future: _resumoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: SelectableText(
                    'Erro ao carregar o painel.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            );
          }

          final resumo = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              _atualizar();
              await _resumoFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  children: [
                    _CartaoResumo(
                      titulo: 'Alunos ativos',
                      valor: '${resumo.alunosAtivos}',
                      subtitulo: 'de ${resumo.totalAlunos} no total',
                      icone: Icons.groups_outlined,
                      cor: AppColors.gold,
                    ),
                    _CartaoResumo(
                      titulo: 'Bloqueados',
                      valor: '${resumo.alunosBloqueados}',
                      subtitulo: 'inadimplentes',
                      icone: Icons.lock_outline,
                      cor: resumo.alunosBloqueados > 0
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                    _CartaoResumo(
                      titulo: 'Matrículas ativas',
                      valor: '${resumo.matriculasAtivas}',
                      icone: Icons.assignment_ind_outlined,
                      cor: AppColors.gold,
                    ),
                    _CartaoResumo(
                      titulo: 'A receber',
                      valor: formatarReais(resumo.mensalidadesAReceber),
                      subtitulo: '${resumo.quantidadeMensalidadesAReceber} cobrança(s)',
                      icone: Icons.receipt_long_outlined,
                      cor: const Color(0xFF4CAF6D),
                    ),
                    _CartaoResumo(
                      titulo: 'A pagar',
                      valor: formatarReais(resumo.contasAPagarEmAberto),
                      subtitulo: '${resumo.quantidadeContasAPagarEmAberto} conta(s)',
                      icone: Icons.request_quote_outlined,
                      cor: AppColors.error,
                    ),
                    _CartaoResumo(
                      titulo: 'Estoque baixo',
                      valor: '${resumo.produtosEstoqueBaixo}',
                      subtitulo: 'produto(s)',
                      icone: Icons.inventory_2_outlined,
                      cor: resumo.produtosEstoqueBaixo > 0
                          ? AppColors.error
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _CaixaCard(resumo: resumo),
                const SizedBox(height: 24),
                const Text('Relatórios', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _LinkRelatorio(
                  icone: Icons.attach_money,
                  titulo: 'Financeiro',
                  subtitulo: 'Contas a receber, a pagar e caixa',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RelatorioFinanceiroScreen(
                        alunoService: widget.alunoService,
                        contaPagarService: widget.contaPagarService,
                        caixaService: widget.caixaService,
                      ),
                    ),
                  ),
                ),
                _LinkRelatorio(
                  icone: Icons.groups_outlined,
                  titulo: 'Alunos',
                  subtitulo: 'Ativos, bloqueados e novos cadastros',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RelatorioAlunosScreen(alunoService: widget.alunoService),
                    ),
                  ),
                ),
                _LinkRelatorio(
                  icone: Icons.assignment_ind_outlined,
                  titulo: 'Matrículas',
                  subtitulo: 'Ativas, encerradas e vencimentos',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RelatorioMatriculasScreen(alunoService: widget.alunoService),
                    ),
                  ),
                ),
                _LinkRelatorio(
                  icone: Icons.inventory_2_outlined,
                  titulo: 'Estoque',
                  subtitulo: 'Produtos, estoque baixo e movimentações',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          RelatorioEstoqueScreen(produtoService: widget.produtoService),
                    ),
                  ),
                ),
                _LinkRelatorio(
                  icone: Icons.monitor_weight_outlined,
                  titulo: 'Evolução física',
                  subtitulo: 'Peso, IMC e medidas ao longo do tempo',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EvolucaoFisicaScreen(alunoService: widget.alunoService),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CartaoResumo extends StatelessWidget {
  const _CartaoResumo({
    required this.titulo,
    required this.valor,
    this.subtitulo,
    required this.icone,
    required this.cor,
  });

  final String titulo;
  final String valor;
  final String? subtitulo;
  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icone, color: cor, size: 22),
          Text(
            valor,
            style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 20),
          ),
          Text(titulo, style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
          if (subtitulo != null)
            Text(
              subtitulo!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _CaixaCard extends StatelessWidget {
  const _CaixaCard({required this.resumo});

  final DashboardResumo resumo;

  @override
  Widget build(BuildContext context) {
    final caixa = resumo.caixaAberto;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Caixa', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (caixa == null)
            const Text(
              'Nenhum caixa aberto no momento.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            Text('Saldo esperado: ${formatarReais(resumo.saldoEsperadoCaixa ?? 0)}'),
            const SizedBox(height: 4),
            Text(
              'Aberto por ${caixa.abertoPorNome}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Movimentações recentes',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            if (resumo.movimentacoesRecentes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Nenhuma movimentação ainda.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              )
            else
              ...resumo.movimentacoesRecentes.take(5).map(
                (mov) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(mov.tipo.label, style: const TextStyle(fontSize: 13)),
                      Text(
                        formatarReais(mov.valor),
                        style: TextStyle(
                          fontSize: 13,
                          color: mov.valor >= 0
                              ? const Color(0xFF4CAF6D)
                              : AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _LinkRelatorio extends StatelessWidget {
  const _LinkRelatorio({
    required this.icone,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icone;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icone, color: AppColors.gold),
        title: Text(titulo),
        subtitle: Text(subtitulo, style: const TextStyle(color: AppColors.textSecondary)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}
