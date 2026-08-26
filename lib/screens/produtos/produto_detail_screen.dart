import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/movimentacao_estoque.dart';
import '../../models/permission.dart';
import '../../models/produto.dart';
import '../../services/permission_service.dart';
import '../../services/produto_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import 'produto_form_screen.dart';

/// Detalhes de um produto — estoque atual, estoque mínimo, custo, preço e
/// o histórico completo de movimentações. Também é o ponto de entrada
/// pras 3 ações de estoque (entrada/saída/ajuste) e pra editar/desativar
/// o cadastro, cada uma atrás da sua própria permissão granular.
class ProdutoDetailScreen extends StatelessWidget {
  const ProdutoDetailScreen({
    super.key,
    required this.produtoService,
    required this.staffAtual,
    required this.produtoId,
  });

  final ProdutoService produtoService;
  final AppUser staffAtual;
  final String produtoId;

  bool get _podeAlterar => PermissionService.has(staffAtual, Permission.alterarProdutos);
  bool get _podeExcluir => PermissionService.has(staffAtual, Permission.excluirProdutos);
  bool get _podeMovimentar => PermissionService.has(staffAtual, Permission.movimentarEstoque);

  /// `acessarProdutos` (que já trouxe o staff até esta tela) cobre o
  /// cadastro do produto (nome, código, categoria, custo, preço);
  /// `acessarEstoque` é quem libera especificamente o bloco de estoque
  /// (quantidade atual/mínima e o histórico de movimentações) — as duas
  /// permissões são independentes, conforme pedido.
  bool get _podeVerEstoque => PermissionService.has(staffAtual, Permission.acessarEstoque);

  String _formatarQuantidade(double valor) {
    return valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : valor.toString();
  }

  String _formatarDataHora(DateTime? data) {
    if (data == null) return '—';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year} '
        '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmarDesativacao(BuildContext context, Produto produto) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(produto.ativo ? 'Desativar produto' : 'Reativar produto'),
        content: Text(
          produto.ativo
              ? 'O produto "${produto.nome}" deixa de aparecer na lista padrão. '
                    'O histórico de movimentações continua preservado.'
              : 'O produto "${produto.nome}" volta a aparecer na lista padrão.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(produto.ativo ? 'DESATIVAR' : 'REATIVAR'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await produtoService.definirAtivo(produto.id!, !produto.ativo);
    }
  }

  void _abrirDialogMovimentacao(
    BuildContext context,
    Produto produto,
    TipoMovimentacaoEstoque tipo,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _MovimentacaoEstoqueDialog(
        produtoService: produtoService,
        staffAtual: staffAtual,
        produto: produto,
        tipo: tipo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do produto')),
      body: StreamBuilder<Produto?>(
        stream: produtoService.watchProduto(produtoId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final produto = snapshot.data;
          if (produto == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Produto não encontrado.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return StreamBuilder<List<MovimentacaoEstoque>>(
            stream: produtoService.watchMovimentacoes(produtoId),
            builder: (context, movSnapshot) {
              final movimentacoes = movSnapshot.data ?? [];

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: produto.estoqueBaixo
                            ? AppColors.error.withValues(alpha: 0.6)
                            : AppColors.surfaceHigh,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                produto.nome,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            if (!produto.ativo)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.textSecondary.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text(
                                  'Inativo',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${produto.codigo} · ${produto.categoria}',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        if (_podeVerEstoque) ...[
                          _LinhaDetalhe(
                            'Estoque atual',
                            '${_formatarQuantidade(produto.estoqueAtual)} ${produto.unidadeMedida}',
                            destaque: true,
                            cor: produto.estoqueBaixo ? AppColors.error : AppColors.textPrimary,
                          ),
                          _LinhaDetalhe(
                            'Estoque mínimo',
                            '${_formatarQuantidade(produto.estoqueMinimo)} ${produto.unidadeMedida}',
                          ),
                        ],
                        _LinhaDetalhe('Preço de custo', formatarReais(produto.precoCusto)),
                        _LinhaDetalhe('Preço de venda', formatarReais(produto.precoVenda)),
                        if (produto.fornecedor != null)
                          _LinhaDetalhe('Fornecedor', produto.fornecedor!),
                        if (_podeVerEstoque && produto.estoqueBaixo) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Estoque abaixo do mínimo.',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_podeMovimentar)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _abrirDialogMovimentacao(
                              context,
                              produto,
                              TipoMovimentacaoEstoque.entrada,
                            ),
                            icon: const Icon(Icons.arrow_downward),
                            label: const Text('ENTRADA'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _abrirDialogMovimentacao(
                              context,
                              produto,
                              TipoMovimentacaoEstoque.saida,
                            ),
                            icon: const Icon(Icons.arrow_upward),
                            label: const Text('SAÍDA'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _abrirDialogMovimentacao(
                              context,
                              produto,
                              TipoMovimentacaoEstoque.ajuste,
                            ),
                            icon: const Icon(Icons.tune),
                            label: const Text('AJUSTE'),
                          ),
                        ),
                      ],
                    ),
                  if (_podeAlterar || _podeExcluir) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_podeAlterar)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProdutoFormScreen(
                                    produtoService: produtoService,
                                    staffAtual: staffAtual,
                                    produto: produto,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('EDITAR'),
                            ),
                          ),
                        if (_podeAlterar && _podeExcluir) const SizedBox(width: 8),
                        if (_podeExcluir)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _confirmarDesativacao(context, produto),
                              icon: Icon(
                                produto.ativo ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              ),
                              label: Text(produto.ativo ? 'DESATIVAR' : 'REATIVAR'),
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (_podeVerEstoque) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Histórico de movimentações',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (movimentacoes.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Nenhuma movimentação ainda.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    else
                      ...movimentacoes.map(
                        (mov) => _MovimentacaoTile(
                          mov: mov,
                          unidadeMedida: produto.unidadeMedida,
                          formatarQuantidade: _formatarQuantidade,
                          formatarDataHora: _formatarDataHora,
                        ),
                      ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _LinhaDetalhe extends StatelessWidget {
  const _LinhaDetalhe(this.label, this.valor, {this.destaque = false, this.cor});

  final String label;
  final String valor;
  final bool destaque;
  final Color? cor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(
            valor,
            style: TextStyle(
              color: cor ?? AppColors.textPrimary,
              fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovimentacaoTile extends StatelessWidget {
  const _MovimentacaoTile({
    required this.mov,
    required this.unidadeMedida,
    required this.formatarQuantidade,
    required this.formatarDataHora,
  });

  final MovimentacaoEstoque mov;
  final String unidadeMedida;
  final String Function(double) formatarQuantidade;
  final String Function(DateTime?) formatarDataHora;

  Color _cor() => mov.quantidade >= 0 ? const Color(0xFF4CAF6D) : AppColors.error;

  @override
  Widget build(BuildContext context) {
    final cor = _cor();
    final sinal = mov.quantidade >= 0 ? '+' : '';
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
                Text(mov.tipo.label, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (mov.motivo != null)
                  Text(
                    mov.motivo!,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                Text(
                  '${formatarDataHora(mov.criadoEm)} · ${mov.staffNome} · '
                  '${formatarQuantidade(mov.estoqueAnterior)} → '
                  '${formatarQuantidade(mov.estoquePosterior)} $unidadeMedida',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            '$sinal${formatarQuantidade(mov.quantidade)}',
            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// Diálogo reutilizado pelas 3 movimentações (entrada/saída/ajuste) —
/// mesmo padrão de `_MovimentacaoDialog` em `caixa_screen.dart`, evita
/// duplicar 3 telas quase idênticas.
class _MovimentacaoEstoqueDialog extends StatefulWidget {
  const _MovimentacaoEstoqueDialog({
    required this.produtoService,
    required this.staffAtual,
    required this.produto,
    required this.tipo,
  });

  final ProdutoService produtoService;
  final AppUser staffAtual;
  final Produto produto;
  final TipoMovimentacaoEstoque tipo;

  @override
  State<_MovimentacaoEstoqueDialog> createState() => _MovimentacaoEstoqueDialogState();
}

class _MovimentacaoEstoqueDialogState extends State<_MovimentacaoEstoqueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantidadeController = TextEditingController();
  final _motivoController = TextEditingController();
  bool _isSaving = false;
  String? _erro;

  @override
  void dispose() {
    _quantidadeController.dispose();
    _motivoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _erro = null;
    });
    try {
      final motivo = _motivoController.text.trim().isEmpty
          ? null
          : _motivoController.text.trim();
      final quantidadeDigitada = double.parse(_quantidadeController.text.trim());

      switch (widget.tipo) {
        case TipoMovimentacaoEstoque.entrada:
          await widget.produtoService.registrarEntrada(
            widget.produto.id!,
            quantidade: quantidadeDigitada,
            motivo: motivo,
            staffUid: widget.staffAtual.uid,
            staffNome: widget.staffAtual.nome,
          );
        case TipoMovimentacaoEstoque.saida:
          await widget.produtoService.registrarSaida(
            widget.produto.id!,
            quantidade: quantidadeDigitada,
            motivo: motivo,
            staffUid: widget.staffAtual.uid,
            staffNome: widget.staffAtual.nome,
          );
        case TipoMovimentacaoEstoque.ajuste:
          await widget.produtoService.registrarAjuste(
            widget.produto.id!,
            quantidade: quantidadeDigitada,
            motivo: motivo,
            staffUid: widget.staffAtual.uid,
            staffNome: widget.staffAtual.nome,
          );
      }
      if (mounted) Navigator.of(context).pop();
    } on ProdutoServiceException catch (e) {
      setState(() => _erro = e.message);
    } catch (_) {
      setState(() => _erro = 'Erro ao registrar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _titulo => switch (widget.tipo) {
    TipoMovimentacaoEstoque.entrada => 'Entrada de estoque',
    TipoMovimentacaoEstoque.saida => 'Saída de estoque',
    TipoMovimentacaoEstoque.ajuste => 'Ajuste de estoque',
  };

  String get _rotuloQuantidade => widget.tipo == TipoMovimentacaoEstoque.ajuste
      ? 'Quantidade (pode ser negativa)'
      : 'Quantidade';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.produto.nome,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantidadeController,
              keyboardType: TextInputType.numberWithOptions(
                decimal: true,
                signed: widget.tipo == TipoMovimentacaoEstoque.ajuste,
              ),
              decoration: InputDecoration(labelText: _rotuloQuantidade),
              validator: (value) {
                final quantidade = double.tryParse((value ?? '').trim());
                if (quantidade == null) return 'Informe um valor válido.';
                if (widget.tipo != TipoMovimentacaoEstoque.ajuste && quantidade <= 0) {
                  return 'A quantidade deve ser maior que zero.';
                }
                if (quantidade == 0) return 'Informe um valor diferente de zero.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _motivoController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 8),
              Text(_erro!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
        TextButton(
          onPressed: _isSaving ? null : _confirmar,
          child: const Text('CONFIRMAR'),
        ),
      ],
    );
  }
}
