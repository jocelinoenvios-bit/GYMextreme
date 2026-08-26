import 'package:flutter/material.dart';

import '../../models/caixa.dart';
import '../../models/caixa_movimentacao.dart';
import '../../models/conta_pagar.dart';
import '../../models/conta_receber.dart';
import '../../services/aluno_service.dart';
import '../../services/caixa_service.dart';
import '../../services/conta_pagar_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import '../../utils/relatorio_financeiro.dart';
import '../../utils/status_conta_pagar.dart';
import '../../utils/status_conta_receber.dart';

/// Relatório financeiro — contas a receber, contas a pagar e as
/// movimentações do caixa aberto, com filtro por período de vencimento.
/// Cada aba carrega seus dados sob demanda (`Future`, sem listener
/// permanente) a partir dos serviços já existentes — nenhuma consulta
/// nova ao Firestore.
class RelatorioFinanceiroScreen extends StatefulWidget {
  const RelatorioFinanceiroScreen({
    super.key,
    required this.alunoService,
    required this.contaPagarService,
    required this.caixaService,
  });

  final AlunoService alunoService;
  final ContaPagarService contaPagarService;
  final CaixaService caixaService;

  @override
  State<RelatorioFinanceiroScreen> createState() => _RelatorioFinanceiroScreenState();
}

class _RelatorioFinanceiroScreenState extends State<RelatorioFinanceiroScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime? _de;
  DateTime? _ate;

  late Future<List<ContaReceber>> _contasReceberFuture;
  late Future<List<ContaPagar>> _contasPagarFuture;
  late Future<_DadosCaixa> _caixaFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _contasReceberFuture = widget.alunoService.watchTodasContasReceber().first;
    _contasPagarFuture = widget.contaPagarService.watchContasPagar().first;
    _caixaFuture = _carregarCaixa();
  }

  Future<_DadosCaixa> _carregarCaixa() async {
    final caixaAberto = await widget.caixaService.watchCaixaAberto().first;
    if (caixaAberto == null) {
      return const _DadosCaixa(caixaAberto: null, movimentacoes: []);
    }
    final movimentacoes = await widget.caixaService.watchMovimentacoes(caixaAberto.id!).first;
    return _DadosCaixa(caixaAberto: caixaAberto, movimentacoes: movimentacoes);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _escolherData(bool inicio) async {
    final atual = inicio ? _de : _ate;
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 3),
      helpText: inicio ? 'Vencimento de' : 'Vencimento até',
    );
    if (picked == null) return;
    setState(() {
      if (inicio) {
        _de = picked;
      } else {
        _ate = picked;
      }
    });
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório financeiro'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'A RECEBER'), Tab(text: 'A PAGAR'), Tab(text: 'CAIXA')],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(true),
                    child: Text(_de == null ? 'Período de' : 'De: ${_formatarData(_de!)}'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _escolherData(false),
                    child: Text(_ate == null ? 'Período até' : 'Até: ${_formatarData(_ate!)}'),
                  ),
                ),
                if (_de != null || _ate != null)
                  IconButton(
                    tooltip: 'Limpar período',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() {
                      _de = null;
                      _ate = null;
                    }),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _AbaContasReceber(future: _contasReceberFuture, de: _de, ate: _ate),
                _AbaContasPagar(future: _contasPagarFuture, de: _de, ate: _ate),
                _AbaCaixa(future: _caixaFuture, de: _de, ate: _ate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AbaContasReceber extends StatelessWidget {
  const _AbaContasReceber({required this.future, required this.de, required this.ate});

  final Future<List<ContaReceber>> future;
  final DateTime? de;
  final DateTime? ate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContaReceber>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar.\n\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        final todas = snapshot.data ?? [];
        final filtradas = filtrarContasReceberPorPeriodo(todas, de: de, ate: ate);
        final totais = calcularTotaisContasReceber(filtradas);

        if (filtradas.isEmpty) {
          return const Center(
            child: Text(
              'Nenhuma cobrança encontrada no período.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CartaoTotais(
              linhas: [
                ('Em aberto', totais.totalEmAberto, AppColors.gold),
                ('Vencido', totais.totalVencido, AppColors.error),
                ('Recebido', totais.totalPago, const Color(0xFF4CAF6D)),
              ],
              quantidade: totais.quantidade,
            ),
            const SizedBox(height: 16),
            ...filtradas.map(
              (conta) => _LinhaConta(
                titulo: conta.descricao,
                subtitulo: 'Venc. ${_fmt(conta.vencimento)}',
                valor: conta.saldoDevedor > 0 ? conta.saldoDevedor : (conta.valorPago ?? 0),
                statusLabel: calcularStatusEfetivo(conta).label,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AbaContasPagar extends StatelessWidget {
  const _AbaContasPagar({required this.future, required this.de, required this.ate});

  final Future<List<ContaPagar>> future;
  final DateTime? de;
  final DateTime? ate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ContaPagar>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar.\n\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        final todas = snapshot.data ?? [];
        final filtradas = filtrarContasPagarPorPeriodo(todas, de: de, ate: ate);
        final totais = calcularTotaisContasPagar(filtradas);

        if (filtradas.isEmpty) {
          return const Center(
            child: Text(
              'Nenhuma despesa encontrada no período.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CartaoTotais(
              linhas: [
                ('Em aberto', totais.totalEmAberto, AppColors.gold),
                ('Vencido', totais.totalVencido, AppColors.error),
                ('Pago', totais.totalPago, const Color(0xFF4CAF6D)),
              ],
              quantidade: totais.quantidade,
            ),
            const SizedBox(height: 16),
            ...filtradas.map(
              (conta) => _LinhaConta(
                titulo: '${conta.fornecedor} · ${conta.descricao}',
                subtitulo: 'Venc. ${_fmt(conta.vencimento)}',
                valor: conta.saldoAPagar > 0 ? conta.saldoAPagar : (conta.valorPago ?? 0),
                statusLabel: calcularStatusEfetivoContaPagar(conta).label,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CartaoTotais extends StatelessWidget {
  const _CartaoTotais({required this.linhas, required this.quantidade});

  final List<(String, double, Color)> linhas;
  final int quantidade;

  @override
  Widget build(BuildContext context) {
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
          Text('$quantidade registro(s) no período', style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          for (final (label, valor, cor) in linhas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label),
                  Text(
                    formatarReais(valor),
                    style: TextStyle(color: cor, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaConta extends StatelessWidget {
  const _LinhaConta({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.statusLabel,
  });

  final String titulo;
  final String subtitulo;
  final double valor;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  '$subtitulo · $statusLabel',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(formatarReais(valor), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DadosCaixa {
  const _DadosCaixa({required this.caixaAberto, required this.movimentacoes});

  final Caixa? caixaAberto;
  final List<CaixaMovimentacao> movimentacoes;
}

/// Só mostra o caixa ATUALMENTE aberto (se houver) — o histórico de
/// sessões fechadas é visto na própria tela de Controle de Caixa. Não há
/// consulta entre sessões de caixa nesta fase (evita uma
/// `collectionGroup` nova sobre `movimentacoes`, que colidiria com a
/// mesma subcoleção usada pelos produtos — ver auditoria da Fase 1F).
class _AbaCaixa extends StatelessWidget {
  const _AbaCaixa({required this.future, required this.de, required this.ate});

  final Future<_DadosCaixa> future;
  final DateTime? de;
  final DateTime? ate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DadosCaixa>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erro ao carregar.\n\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error),
            ),
          );
        }

        final dados = snapshot.data!;
        if (dados.caixaAberto == null) {
          return const Center(
            child: Text(
              'Nenhum caixa aberto no momento.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        final filtradas = filtrarMovimentacoesCaixaPorPeriodo(
          dados.movimentacoes,
          de: de,
          ate: ate,
        );
        final saldo =
            dados.caixaAberto!.valorInicial + somarMovimentacoesCaixa(filtradas);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceHigh),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aberto por ${dados.caixaAberto!.abertoPorNome}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Saldo no período', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        formatarReais(saldo),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filtradas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Nenhuma movimentação no período.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...filtradas.map(
                (mov) => _LinhaConta(
                  titulo: mov.tipo.label,
                  subtitulo:
                      '${mov.staffNome}${mov.criadoEm != null ? ' · ${_fmt(mov.criadoEm!)}' : ''}',
                  valor: mov.valor,
                  statusLabel: mov.descricao ?? '',
                ),
              ),
          ],
        );
      },
    );
  }
}

String _fmt(DateTime data) {
  return '${data.day.toString().padLeft(2, '0')}/'
      '${data.month.toString().padLeft(2, '0')}/${data.year}';
}
