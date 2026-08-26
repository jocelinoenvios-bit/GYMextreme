import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/permission.dart';
import '../../models/produto.dart';
import '../../services/permission_service.dart';
import '../../services/produto_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import 'produto_detail_screen.dart';
import 'produto_form_screen.dart';

/// Lista de produtos — busca por nome/código, filtro por categoria,
/// ativo/inativo e estoque baixo. Cadastrar exige `cadastrarProdutos`;
/// visualizar a lista exige `acessarProdutos`.
class ProdutosListScreen extends StatefulWidget {
  const ProdutosListScreen({
    super.key,
    required this.produtoService,
    required this.staffAtual,
  });

  final ProdutoService produtoService;
  final AppUser staffAtual;

  @override
  State<ProdutosListScreen> createState() => _ProdutosListScreenState();
}

class _ProdutosListScreenState extends State<ProdutosListScreen> {
  final _buscaController = TextEditingController();
  String? _filtroCategoria;
  bool _mostrarInativos = false;
  bool _somenteEstoqueBaixo = false;

  bool get _podeCadastrar =>
      PermissionService.has(widget.staffAtual, Permission.cadastrarProdutos);

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  void _abrirCadastro(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProdutoFormScreen(
          produtoService: widget.produtoService,
          staffAtual: widget.staffAtual,
        ),
      ),
    );
  }

  void _abrirDetalhes(BuildContext context, Produto produto) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProdutoDetailScreen(
          produtoService: widget.produtoService,
          staffAtual: widget.staffAtual,
          produtoId: produto.id!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produtos')),
      body: StreamBuilder<List<Produto>>(
        stream: widget.produtoService.watchProdutos(),
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
                    'Erro ao carregar os produtos.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            );
          }

          final todos = snapshot.data ?? [];
          final categorias = todos.map((p) => p.categoria).toSet().toList()..sort();

          final busca = _buscaController.text.trim().toLowerCase();
          var produtos = todos;
          if (!_mostrarInativos) {
            produtos = produtos.where((p) => p.ativo).toList();
          }
          if (_filtroCategoria != null) {
            produtos = produtos.where((p) => p.categoria == _filtroCategoria).toList();
          }
          if (_somenteEstoqueBaixo) {
            produtos = produtos.where((p) => p.estoqueBaixo).toList();
          }
          if (busca.isNotEmpty) {
            produtos = produtos
                .where(
                  (p) =>
                      p.nome.toLowerCase().contains(busca) ||
                      p.codigo.toLowerCase().contains(busca),
                )
                .toList();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _buscaController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nome ou código',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<String?>(
                        initialValue: _filtroCategoria,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Categoria', isDense: true),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Todas')),
                          ...categorias.map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (valor) => setState(() => _filtroCategoria = valor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Estoque baixo'),
                      selected: _somenteEstoqueBaixo,
                      onSelected: (valor) => setState(() => _somenteEstoqueBaixo = valor),
                    ),
                    const SizedBox(width: 12),
                    FilterChip(
                      label: const Text('Mostrar inativos'),
                      selected: _mostrarInativos,
                      onSelected: (valor) => setState(() => _mostrarInativos = valor),
                    ),
                  ],
                ),
              ),
              if (_podeCadastrar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirCadastro(context),
                      icon: const Icon(Icons.add),
                      label: const Text('NOVO PRODUTO'),
                    ),
                  ),
                ),
              Expanded(
                child: produtos.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nenhum produto encontrado.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: produtos.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final produto = produtos[index];
                          return _ProdutoCard(
                            produto: produto,
                            onTap: () => _abrirDetalhes(context, produto),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProdutoCard extends StatelessWidget {
  const _ProdutoCard({required this.produto, required this.onTap});

  final Produto produto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corBorda = produto.estoqueBaixo ? AppColors.error : AppColors.surfaceHigh;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: corBorda.withValues(alpha: produto.estoqueBaixo ? 0.6 : 1)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(child: Text(produto.nome)),
            if (!produto.ativo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Inativo',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
            if (produto.estoqueBaixo) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Estoque baixo',
                  style: TextStyle(color: AppColors.error, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          '${produto.codigo} · ${produto.categoria} · '
          '${formatarReais(produto.precoVenda)} · '
          'Estoque: ${produto.estoqueAtual == produto.estoqueAtual.roundToDouble() ? produto.estoqueAtual.toStringAsFixed(0) : produto.estoqueAtual} '
          '${produto.unidadeMedida}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}
