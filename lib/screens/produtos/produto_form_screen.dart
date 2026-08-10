import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/produto.dart';
import '../../services/produto_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';

/// Cadastra um produto novo ou edita um existente (passe [produto] para
/// entrar no modo edição). O estoque atual NUNCA é editável por aqui
/// depois de criado — só na criação (estoque inicial) ou através das
/// movimentações de entrada/saída/ajuste (ver `ProdutoDetailScreen`),
/// pra preservar a rastreabilidade completa de toda alteração.
class ProdutoFormScreen extends StatefulWidget {
  const ProdutoFormScreen({
    super.key,
    required this.produtoService,
    required this.staffAtual,
    this.produto,
  });

  final ProdutoService produtoService;
  final AppUser staffAtual;
  final Produto? produto;

  bool get _ehEdicao => produto != null;

  @override
  State<ProdutoFormScreen> createState() => _ProdutoFormScreenState();
}

class _ProdutoFormScreenState extends State<ProdutoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeController = TextEditingController(text: widget.produto?.nome);
  late final _codigoController = TextEditingController(text: widget.produto?.codigo);
  late final _categoriaController = TextEditingController(text: widget.produto?.categoria);
  late final _descricaoController = TextEditingController(text: widget.produto?.descricao);
  late final _unidadeMedidaController = TextEditingController(
    text: widget.produto?.unidadeMedida ?? 'un',
  );
  late final _precoCustoController = TextEditingController(
    text: formatarReais(widget.produto?.precoCusto ?? 0).replaceFirst('R\$ ', ''),
  );
  late final _precoVendaController = TextEditingController(
    text: widget.produto != null
        ? formatarReais(widget.produto!.precoVenda).replaceFirst('R\$ ', '')
        : null,
  );
  late final _estoqueInicialController = TextEditingController(text: '0');
  late final _estoqueMinimoController = TextEditingController(
    text: widget.produto?.estoqueMinimo.toString() ?? '0',
  );
  late final _fornecedorController = TextEditingController(text: widget.produto?.fornecedor);

  bool _isSaving = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _codigoController.dispose();
    _categoriaController.dispose();
    _descricaoController.dispose();
    _unidadeMedidaController.dispose();
    _precoCustoController.dispose();
    _precoVendaController.dispose();
    _estoqueInicialController.dispose();
    _estoqueMinimoController.dispose();
    _fornecedorController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final precoCusto = parseValorReais(_precoCustoController.text) ?? 0;
    final precoVenda = parseValorReais(_precoVendaController.text)!;
    final estoqueMinimo = double.parse(_estoqueMinimoController.text.trim());
    final descricao = _descricaoController.text.trim().isEmpty
        ? null
        : _descricaoController.text.trim();
    final fornecedor = _fornecedorController.text.trim().isEmpty
        ? null
        : _fornecedorController.text.trim();

    setState(() => _isSaving = true);
    try {
      if (widget._ehEdicao) {
        await widget.produtoService.atualizarProduto(
          widget.produto!.id!,
          nome: _nomeController.text.trim(),
          codigo: _codigoController.text.trim(),
          categoria: _categoriaController.text.trim(),
          descricao: descricao,
          unidadeMedida: _unidadeMedidaController.text.trim(),
          precoCusto: precoCusto,
          precoVenda: precoVenda,
          estoqueMinimo: estoqueMinimo,
          fornecedor: fornecedor,
        );
      } else {
        final estoqueInicial = double.parse(_estoqueInicialController.text.trim());
        await widget.produtoService.criarProduto(
          nome: _nomeController.text.trim(),
          codigo: _codigoController.text.trim(),
          categoria: _categoriaController.text.trim(),
          descricao: descricao,
          unidadeMedida: _unidadeMedidaController.text.trim(),
          precoCusto: precoCusto,
          precoVenda: precoVenda,
          estoqueInicial: estoqueInicial,
          estoqueMinimo: estoqueMinimo,
          fornecedor: fornecedor,
          staffUid: widget.staffAtual.uid,
          staffNome: widget.staffAtual.nome,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Erro ao salvar o produto. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget._ehEdicao ? 'Editar produto' : 'Novo produto')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nomeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Informe o nome.' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _codigoController,
                        decoration: const InputDecoration(labelText: 'Código/SKU'),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty) ? 'Informe o código.' : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _categoriaController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(labelText: 'Categoria'),
                        validator: (value) => (value == null || value.trim().isEmpty)
                            ? 'Informe a categoria.'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descricaoController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _unidadeMedidaController,
                  decoration: const InputDecoration(
                    labelText: 'Unidade de medida',
                    helperText: 'Ex.: un, kg, cx',
                  ),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Informe a unidade.' : null,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _precoCustoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Preço de custo (R\$)'),
                        validator: (value) =>
                            parseValorReais(value ?? '0') == null ? 'Valor inválido.' : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _precoVendaController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Preço de venda (R\$)'),
                        validator: (value) {
                          final valor = parseValorReais(value ?? '');
                          if (valor == null) return 'Informe um valor válido.';
                          if (valor <= 0) return 'O valor deve ser maior que zero.';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (!widget._ehEdicao)
                      Expanded(
                        child: TextFormField(
                          controller: _estoqueInicialController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Estoque inicial'),
                          validator: (value) =>
                              double.tryParse((value ?? '').trim()) == null
                              ? 'Valor inválido.'
                              : null,
                        ),
                      ),
                    if (!widget._ehEdicao) const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _estoqueMinimoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Estoque mínimo'),
                        validator: (value) =>
                            double.tryParse((value ?? '').trim()) == null
                            ? 'Valor inválido.'
                            : null,
                      ),
                    ),
                  ],
                ),
                if (widget._ehEdicao) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'O estoque atual só muda por entrada, saída ou ajuste — '
                    'veja a tela de detalhes do produto.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _fornecedorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Fornecedor (opcional)'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleSave,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.black,
                          ),
                        )
                      : Text(widget._ehEdicao ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR PRODUTO'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
