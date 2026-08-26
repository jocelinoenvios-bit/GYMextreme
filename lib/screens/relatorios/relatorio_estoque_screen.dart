import 'package:flutter/material.dart';

import '../../models/movimentacao_estoque.dart';
import '../../models/produto.dart';
import '../../services/produto_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import '../../utils/relatorio_estoque.dart';

/// Relatório de estoque — produtos cadastrados, estoque atual, produtos
/// abaixo do mínimo e, por produto selecionado, o histórico de
/// movimentações (entrada/saída/ajuste) num período. Carrega uma vez a
/// partir de `ProdutoService.watchProdutos()`/`watchMovimentacoes()`, já
/// existentes.
///
/// Não existe (e não deve existir) uma consulta de movimentações entre
/// TODOS os produtos de uma vez: `produtos/{id}/movimentacoes` e
/// `caixas/{id}/movimentacoes` têm o mesmo nome de subcoleção, então uma
/// regra de collection group pra "movimentacoes" aplicaria uma única
/// condição de autorização aos dois — inseguro. Por isso o histórico é
/// sempre por produto, um de cada vez.
class RelatorioEstoqueScreen extends StatefulWidget {
  const RelatorioEstoqueScreen({super.key, required this.produtoService});

  final ProdutoService produtoService;

  @override
  State<RelatorioEstoqueScreen> createState() => _RelatorioEstoqueScreenState();
}

class _RelatorioEstoqueScreenState extends State<RelatorioEstoqueScreen> {
  late Future<List<Produto>> _future;
  String? _produtoSelecionadoId;
  Future<List<MovimentacaoEstoque>>? _movimentacoesFuture;
  DateTime? _de;
  DateTime? _ate;

  @override
  void initState() {
    super.initState();
    _future = widget.produtoService.watchProdutos().first;
  }

  void _selecionarProduto(String? produtoId) {
    setState(() {
      _produtoSelecionadoId = produtoId;
      _movimentacoesFuture = produtoId == null
          ? null
          : widget.produtoService.watchMovimentacoes(produtoId).first;
    });
  }

  Future<void> _escolherData(bool inicio) async {
    final atual = inicio ? _de : _ate;
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 1),
      helpText: inicio ? 'Movimentação de' : 'Movimentação até',
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

  String _fmt(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatório de estoque')),
      body: FutureBuilder<List<Produto>>(
        future: _future,
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

          final produtos = snapshot.data ?? [];
          final resumo = calcularResumoEstoque(produtos);
          final abaixoDoMinimo = produtos.where((p) => p.ativo && p.estoqueBaixo).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _CartaoNumero('Cadastrados', '${resumo.totalProdutos}', AppColors.textPrimary),
                  _CartaoNumero('Ativos', '${resumo.produtosAtivos}', const Color(0xFF4CAF6D)),
                  _CartaoNumero(
                    'Estoque baixo',
                    '${resumo.produtosEstoqueBaixo}',
                    resumo.produtosEstoqueBaixo > 0 ? AppColors.error : AppColors.textSecondary,
                  ),
                  _CartaoNumero(
                    'Valor em estoque',
                    formatarReais(resumo.valorTotalEstoqueCusto),
                    AppColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Abaixo do estoque mínimo',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (abaixoDoMinimo.isEmpty)
                const Text(
                  'Nenhum produto abaixo do mínimo.',
                  style: TextStyle(color: AppColors.textSecondary),
                )
              else
                ...abaixoDoMinimo.map(
                  (p) => _LinhaProduto(
                    nome: p.nome,
                    detalhe:
                        '${p.estoqueAtual.toStringAsFixed(0)} / '
                        'mín. ${p.estoqueMinimo.toStringAsFixed(0)} ${p.unidadeMedida}',
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Movimentações por produto',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                initialValue: _produtoSelecionadoId,
                isExpanded: true,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Selecione um produto',
                ),
                items: produtos
                    .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nome)))
                    .toList(),
                onChanged: _selecionarProduto,
              ),
              if (_movimentacoesFuture != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _escolherData(true),
                        child: Text(_de == null ? 'De' : _fmt(_de!)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _escolherData(false),
                        child: Text(_ate == null ? 'Até' : _fmt(_ate!)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<MovimentacaoEstoque>>(
                  future: _movimentacoesFuture,
                  builder: (context, movSnap) {
                    if (movSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (movSnap.hasError) {
                      return Text(
                        'Erro ao carregar movimentações.\n\n${movSnap.error}',
                        style: const TextStyle(color: AppColors.error),
                      );
                    }

                    final todas = movSnap.data ?? [];
                    final filtradas = filtrarMovimentacoesEstoquePorPeriodo(
                      todas,
                      de: _de,
                      ate: _ate,
                    );
                    final totais = calcularTotaisMovimentacaoEstoque(filtradas);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Entradas: ${totais.entradas} (${totais.totalEntradas.toStringAsFixed(0)})'),
                            Text('Saídas: ${totais.saidas} (${totais.totalSaidas.toStringAsFixed(0)})'),
                            Text('Ajustes: ${totais.ajustes}'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (filtradas.isEmpty)
                          const Text(
                            'Nenhuma movimentação no período selecionado.',
                            style: TextStyle(color: AppColors.textSecondary),
                          )
                        else
                          ...filtradas.map((m) => _LinhaMovimentacao(mov: m, fmt: _fmt)),
                      ],
                    );
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CartaoNumero extends StatelessWidget {
  const _CartaoNumero(this.titulo, this.valor, this.cor);
  final String titulo;
  final String valor;
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(valor, style: TextStyle(color: cor, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(titulo, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _LinhaProduto extends StatelessWidget {
  const _LinhaProduto({required this.nome, required this.detalhe});

  final String nome;
  final String detalhe;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(nome)),
          Text(
            detalhe,
            style: const TextStyle(color: AppColors.error, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _LinhaMovimentacao extends StatelessWidget {
  const _LinhaMovimentacao({required this.mov, required this.fmt});

  final MovimentacaoEstoque mov;
  final String Function(DateTime) fmt;

  Color _cor() {
    switch (mov.tipo) {
      case TipoMovimentacaoEstoque.entrada:
        return const Color(0xFF4CAF6D);
      case TipoMovimentacaoEstoque.saida:
        return AppColors.error;
      case TipoMovimentacaoEstoque.ajuste:
        return AppColors.gold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cor = _cor();
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mov.criadoEm != null ? fmt(mov.criadoEm!) : '—'),
                if (mov.motivo != null && mov.motivo!.isNotEmpty)
                  Text(
                    mov.motivo!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${mov.tipo.label} ${mov.quantidade.toStringAsFixed(0)}',
              style: TextStyle(color: cor, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
