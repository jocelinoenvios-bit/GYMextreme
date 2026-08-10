import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/conta_pagar.dart';
import '../../models/permission.dart';
import '../../services/caixa_service.dart';
import '../../services/conta_pagar_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import '../../utils/status_conta_pagar.dart';
import 'conta_pagar_form_screen.dart';
import 'registrar_pagamento_screen.dart';

const _corPago = Color(0xFF4CAF6D);

/// Tela "Contas a Pagar" — todas as despesas da academia, com filtro por
/// status (efetivo, considerando vencimento), fornecedor, categoria e
/// período de vencimento. Cada ação (criar/editar/excluir/pagar) respeita
/// sua própria permissão granular — nunca "qualquer staff".
class ContasPagarListScreen extends StatefulWidget {
  const ContasPagarListScreen({
    super.key,
    required this.contaPagarService,
    required this.caixaService,
    required this.staffAtual,
  });

  final ContaPagarService contaPagarService;
  final CaixaService caixaService;
  final AppUser staffAtual;

  @override
  State<ContasPagarListScreen> createState() => _ContasPagarListScreenState();
}

class _ContasPagarListScreenState extends State<ContasPagarListScreen> {
  StatusContaPagar? _filtroStatus;
  String? _filtroFornecedor;
  String? _filtroCategoria;
  DateTime? _filtroVencimentoDe;
  DateTime? _filtroVencimentoAte;

  bool get _podeCadastrar =>
      PermissionService.has(widget.staffAtual, Permission.cadastrarContasPagar);
  bool get _podeAlterar =>
      PermissionService.has(widget.staffAtual, Permission.alterarContasPagar);
  bool get _podeExcluir =>
      PermissionService.has(widget.staffAtual, Permission.excluirContasPagar);
  bool get _podePagar => PermissionService.has(widget.staffAtual, Permission.pagarContasPagar);

  void _abrirNovaDespesa(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContaPagarFormScreen(
          contaPagarService: widget.contaPagarService,
          staffAtual: widget.staffAtual,
        ),
      ),
    );
  }

  void _abrirEdicao(BuildContext context, ContaPagar conta) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContaPagarFormScreen(
          contaPagarService: widget.contaPagarService,
          staffAtual: widget.staffAtual,
          conta: conta,
        ),
      ),
    );
  }

  void _abrirPagamento(BuildContext context, ContaPagar conta) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RegistrarPagamentoScreen(
          contaPagarService: widget.contaPagarService,
          caixaService: widget.caixaService,
          staffAtual: widget.staffAtual,
          conta: conta,
        ),
      ),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, ContaPagar conta) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir despesa'),
        content: const Text(
          'A despesa fica marcada como cancelada — o registro e o histórico '
          'continuam existindo, só some das pendências.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('VOLTAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await widget.contaPagarService.excluirContaPagar(conta.id!);
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  Color _corDoStatus(StatusContaPagar status) {
    switch (status) {
      case StatusContaPagar.pendente:
        return AppColors.gold;
      case StatusContaPagar.pago:
        return _corPago;
      case StatusContaPagar.vencido:
        return AppColors.error;
      case StatusContaPagar.cancelado:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contas a Pagar')),
      body: StreamBuilder<List<ContaPagar>>(
        stream: widget.contaPagarService.watchContasPagar(),
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
                    'Erro ao carregar as contas a pagar.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            );
          }

          final todas = snapshot.data ?? [];
          final fornecedores = todas.map((c) => c.fornecedor).toSet().toList()..sort();
          final categorias = todas.map((c) => c.categoria).toSet().toList()..sort();

          var contas = todas;
          if (_filtroStatus != null) {
            contas = contas
                .where((c) => calcularStatusEfetivoContaPagar(c) == _filtroStatus)
                .toList();
          }
          if (_filtroFornecedor != null) {
            contas = contas.where((c) => c.fornecedor == _filtroFornecedor).toList();
          }
          if (_filtroCategoria != null) {
            contas = contas.where((c) => c.categoria == _filtroCategoria).toList();
          }
          if (_filtroVencimentoDe != null) {
            contas = contas
                .where((c) => !c.vencimento.isBefore(_filtroVencimentoDe!))
                .toList();
          }
          if (_filtroVencimentoAte != null) {
            contas = contas
                .where((c) => !c.vencimento.isAfter(_filtroVencimentoAte!))
                .toList();
          }

          return Column(
            children: [
              _FiltrosContaPagar(
                fornecedores: fornecedores,
                categorias: categorias,
                filtroStatus: _filtroStatus,
                filtroFornecedor: _filtroFornecedor,
                filtroCategoria: _filtroCategoria,
                filtroVencimentoDe: _filtroVencimentoDe,
                filtroVencimentoAte: _filtroVencimentoAte,
                onStatusChanged: (status) => setState(() => _filtroStatus = status),
                onFornecedorChanged: (f) => setState(() => _filtroFornecedor = f),
                onCategoriaChanged: (c) => setState(() => _filtroCategoria = c),
                onVencimentoDeChanged: (data) => setState(() => _filtroVencimentoDe = data),
                onVencimentoAteChanged: (data) => setState(() => _filtroVencimentoAte = data),
                formatarData: _formatarData,
              ),
              if (_podeCadastrar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirNovaDespesa(context),
                      icon: const Icon(Icons.add),
                      label: const Text('NOVA DESPESA'),
                    ),
                  ),
                ),
              Expanded(
                child: contas.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Nenhuma despesa encontrada.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: contas.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final conta = contas[index];
                          final statusEfetivo = calcularStatusEfetivoContaPagar(conta);
                          final podeAgir =
                              statusEfetivo != StatusContaPagar.pago &&
                              statusEfetivo != StatusContaPagar.cancelado;
                          return _ContaPagarCard(
                            conta: conta,
                            statusEfetivo: statusEfetivo,
                            corStatus: _corDoStatus(statusEfetivo),
                            formatarData: _formatarData,
                            onEditar: (_podeAlterar && podeAgir)
                                ? () => _abrirEdicao(context, conta)
                                : null,
                            onExcluir: (_podeExcluir && podeAgir)
                                ? () => _confirmarExclusao(context, conta)
                                : null,
                            onPagar: (_podePagar && podeAgir)
                                ? () => _abrirPagamento(context, conta)
                                : null,
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

class _FiltrosContaPagar extends StatelessWidget {
  const _FiltrosContaPagar({
    required this.fornecedores,
    required this.categorias,
    required this.filtroStatus,
    required this.filtroFornecedor,
    required this.filtroCategoria,
    required this.filtroVencimentoDe,
    required this.filtroVencimentoAte,
    required this.onStatusChanged,
    required this.onFornecedorChanged,
    required this.onCategoriaChanged,
    required this.onVencimentoDeChanged,
    required this.onVencimentoAteChanged,
    required this.formatarData,
  });

  final List<String> fornecedores;
  final List<String> categorias;
  final StatusContaPagar? filtroStatus;
  final String? filtroFornecedor;
  final String? filtroCategoria;
  final DateTime? filtroVencimentoDe;
  final DateTime? filtroVencimentoAte;
  final ValueChanged<StatusContaPagar?> onStatusChanged;
  final ValueChanged<String?> onFornecedorChanged;
  final ValueChanged<String?> onCategoriaChanged;
  final ValueChanged<DateTime?> onVencimentoDeChanged;
  final ValueChanged<DateTime?> onVencimentoAteChanged;
  final String Function(DateTime) formatarData;

  Future<void> _escolherData(
    BuildContext context,
    DateTime? atual,
    ValueChanged<DateTime?> onChanged,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: atual ?? DateTime.now(),
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 3),
      helpText: 'Vencimento (período)',
    );
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<StatusContaPagar?>(
              initialValue: filtroStatus,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Status', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...StatusContaPagar.values.map(
                  (status) => DropdownMenuItem(value: status, child: Text(status.label)),
                ),
              ],
              onChanged: onStatusChanged,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String?>(
              initialValue: filtroFornecedor,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Fornecedor', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                ...fornecedores.map(
                  (f) => DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis)),
                ),
              ],
              onChanged: onFornecedorChanged,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String?>(
              initialValue: filtroCategoria,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoria', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todas')),
                ...categorias.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                ),
              ],
              onChanged: onCategoriaChanged,
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _escolherData(context, filtroVencimentoDe, onVencimentoDeChanged),
            child: Text(
              filtroVencimentoDe == null
                  ? 'Vencimento de'
                  : 'De: ${formatarData(filtroVencimentoDe!)}',
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: () => _escolherData(context, filtroVencimentoAte, onVencimentoAteChanged),
            child: Text(
              filtroVencimentoAte == null
                  ? 'Vencimento até'
                  : 'Até: ${formatarData(filtroVencimentoAte!)}',
            ),
          ),
        ],
      ),
    );
  }
}

class _ContaPagarCard extends StatelessWidget {
  const _ContaPagarCard({
    required this.conta,
    required this.statusEfetivo,
    required this.corStatus,
    required this.formatarData,
    required this.onEditar,
    required this.onExcluir,
    required this.onPagar,
  });

  final ContaPagar conta;
  final StatusContaPagar statusEfetivo;
  final Color corStatus;
  final String Function(DateTime) formatarData;
  final VoidCallback? onEditar;
  final VoidCallback? onExcluir;
  final VoidCallback? onPagar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: corStatus.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  conta.fornecedor,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: corStatus.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusEfetivo.label,
                  style: TextStyle(color: corStatus, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${conta.descricao} · ${conta.categoria}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Vencimento: ${formatarData(conta.vencimento)} · ${formatarReais(conta.valorFinal)}'
            '${conta.status == StatusContaPagar.pago ? ' · pago em ${formatarData(conta.dataPagamento!)}' : ''}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (onEditar != null || onExcluir != null || onPagar != null) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (onExcluir != null)
                  TextButton(onPressed: onExcluir, child: const Text('EXCLUIR')),
                if (onEditar != null)
                  TextButton(onPressed: onEditar, child: const Text('EDITAR')),
                if (onPagar != null)
                  TextButton(onPressed: onPagar, child: const Text('PAGAR')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
