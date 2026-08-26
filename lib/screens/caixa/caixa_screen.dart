import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/caixa.dart';
import '../../models/caixa_movimentacao.dart';
import '../../models/permission.dart';
import '../../services/caixa_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import 'fechar_caixa_screen.dart';

const _corAberto = Color(0xFF4CAF6D);

/// Tela "Controle de Caixa" — status, saldo inicial, totais por tipo de
/// movimentação, saldo esperado, lista de movimentações, e as ações
/// (abrir/fechar/retirada/suprimento), cada uma com sua própria
/// permissão granular.
class CaixaScreen extends StatelessWidget {
  const CaixaScreen({
    super.key,
    required this.caixaService,
    required this.staffAtual,
  });

  final CaixaService caixaService;
  final AppUser staffAtual;

  bool get _podeAbrir =>
      PermissionService.has(staffAtual, Permission.abrirCaixa);
  bool get _podeFechar =>
      PermissionService.has(staffAtual, Permission.fecharCaixa);
  bool get _podeRetirar =>
      PermissionService.has(staffAtual, Permission.realizarRetiradas);
  bool get _podeSuprir =>
      PermissionService.has(staffAtual, Permission.realizarSuprimentos);
  bool get _podeVerHistorico =>
      PermissionService.has(staffAtual, Permission.consultarRelatorioCaixa);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controle de Caixa'),
        actions: [
          if (_podeVerHistorico)
            IconButton(
              tooltip: 'Histórico de caixas',
              icon: const Icon(Icons.history),
              onPressed: () => _abrirHistorico(context),
            ),
        ],
      ),
      body: StreamBuilder<Caixa?>(
        stream: caixaService.watchCaixaAberto(),
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
                    'Erro ao carregar o caixa.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            );
          }

          final caixa = snapshot.data;
          if (caixa == null) {
            return _SemCaixaAberto(
              podeAbrir: _podeAbrir,
              onAbrir: () => _abrirDialogAbertura(context),
            );
          }
          return _CaixaAbertoView(
            caixa: caixa,
            caixaService: caixaService,
            staffAtual: staffAtual,
            podeFechar: _podeFechar,
            podeRetirar: _podeRetirar,
            podeSuprir: _podeSuprir,
          );
        },
      ),
    );
  }

  void _abrirDialogAbertura(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) =>
          _AbrirCaixaDialog(caixaService: caixaService, staffAtual: staffAtual),
    );
  }

  void _abrirHistorico(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _HistoricoCaixasScreen(caixaService: caixaService),
      ),
    );
  }
}

class _SemCaixaAberto extends StatelessWidget {
  const _SemCaixaAberto({required this.podeAbrir, required this.onAbrir});

  final bool podeAbrir;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.point_of_sale_outlined,
              color: AppColors.textSecondary,
              size: 56,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum caixa aberto no momento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (podeAbrir) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onAbrir,
                icon: const Icon(Icons.add),
                label: const Text('ABRIR CAIXA'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CaixaAbertoView extends StatelessWidget {
  const _CaixaAbertoView({
    required this.caixa,
    required this.caixaService,
    required this.staffAtual,
    required this.podeFechar,
    required this.podeRetirar,
    required this.podeSuprir,
  });

  final Caixa caixa;
  final CaixaService caixaService;
  final AppUser staffAtual;
  final bool podeFechar;
  final bool podeRetirar;
  final bool podeSuprir;

  String _formatarDataHora(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year} '
        '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<CaixaMovimentacao>>(
      stream: caixaService.watchMovimentacoes(caixa.id!),
      builder: (context, snapshot) {
        final movimentacoes = snapshot.data ?? [];
        final totalRecebido = movimentacoes
            .where((m) => m.tipo == TipoMovimentacaoCaixa.recebimento)
            .fold(0.0, (soma, m) => soma + m.valor);
        final totalSuprimentos = movimentacoes
            .where((m) => m.tipo == TipoMovimentacaoCaixa.suprimento)
            .fold(0.0, (soma, m) => soma + m.valor);
        final totalRetiradas = movimentacoes
            .where((m) => m.tipo == TipoMovimentacaoCaixa.retirada)
            .fold(0.0, (soma, m) => soma + m.valor.abs());
        final saldoEsperado =
            caixa.valorInicial +
            movimentacoes.fold(0.0, (soma, m) => soma + m.valor);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _corAberto.withValues(alpha: 0.6)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _corAberto.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Aberto',
                          style: TextStyle(
                            color: _corAberto,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (caixa.abertoEm != null)
                        Text(
                          _formatarDataHora(caixa.abertoEm!),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Aberto por ${caixa.abertoPorNome}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text('Saldo inicial: ${formatarReais(caixa.valorInicial)}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _LinhaTotal('Total recebido', totalRecebido, _corAberto),
            _LinhaTotal(
              'Total de suprimentos',
              totalSuprimentos,
              AppColors.gold,
            ),
            _LinhaTotal('Total de retiradas', totalRetiradas, AppColors.error),
            const Divider(height: 24, color: AppColors.surfaceHigh),
            _LinhaTotal(
              'Saldo esperado',
              saldoEsperado,
              AppColors.textPrimary,
              destaque: true,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (podeRetirar)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirDialogMovimentacao(
                        context,
                        TipoMovimentacaoCaixa.retirada,
                      ),
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('RETIRADA'),
                    ),
                  ),
                if (podeRetirar && podeSuprir) const SizedBox(width: 12),
                if (podeSuprir)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirDialogMovimentacao(
                        context,
                        TipoMovimentacaoCaixa.suprimento,
                      ),
                      icon: const Icon(Icons.arrow_downward),
                      label: const Text('SUPRIMENTO'),
                    ),
                  ),
              ],
            ),
            if (podeFechar) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FecharCaixaScreen(
                        caixaService: caixaService,
                        staffAtual: staffAtual,
                        caixa: caixa,
                        saldoEsperadoAtual: saldoEsperado,
                      ),
                    ),
                  ),
                  child: const Text('FECHAR CAIXA'),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const Text(
              'Movimentações',
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
              ...movimentacoes.map((mov) => _MovimentacaoTile(mov: mov)),
          ],
        );
      },
    );
  }

  void _abrirDialogMovimentacao(
    BuildContext context,
    TipoMovimentacaoCaixa tipo,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _MovimentacaoDialog(
        caixaService: caixaService,
        staffAtual: staffAtual,
        caixaId: caixa.id!,
        tipo: tipo,
      ),
    );
  }
}

class _LinhaTotal extends StatelessWidget {
  const _LinhaTotal(this.label, this.valor, this.cor, {this.destaque = false});

  final String label;
  final double valor;
  final Color cor;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: destaque ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: destaque ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            formatarReais(valor),
            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _MovimentacaoTile extends StatelessWidget {
  const _MovimentacaoTile({required this.mov});

  final CaixaMovimentacao mov;

  Color _cor() {
    switch (mov.tipo) {
      case TipoMovimentacaoCaixa.recebimento:
      case TipoMovimentacaoCaixa.suprimento:
        return mov.valor >= 0 ? _corAberto : AppColors.error;
      case TipoMovimentacaoCaixa.retirada:
      case TipoMovimentacaoCaixa.pagamentoContaPagar:
        return AppColors.error;
      case TipoMovimentacaoCaixa.ajuste:
        return mov.valor >= 0 ? _corAberto : AppColors.error;
    }
  }

  String _formatarHora(DateTime? data) {
    if (data == null) return '';
    return '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cor = _cor();
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
                Text(
                  mov.tipo.label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (mov.descricao != null)
                  Text(
                    mov.descricao!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                Text(
                  '${_formatarHora(mov.criadoEm)} · ${mov.staffNome}'
                  '${mov.formaPagamento != null ? ' · ${mov.formaPagamento}' : ''}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            formatarReais(mov.valor),
            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _AbrirCaixaDialog extends StatefulWidget {
  const _AbrirCaixaDialog({
    required this.caixaService,
    required this.staffAtual,
  });

  final CaixaService caixaService;
  final AppUser staffAtual;

  @override
  State<_AbrirCaixaDialog> createState() => _AbrirCaixaDialogState();
}

class _AbrirCaixaDialogState extends State<_AbrirCaixaDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController(text: '0,00');
  bool _isSaving = false;
  String? _erro;

  @override
  void dispose() {
    _valorController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _erro = null;
    });
    try {
      await widget.caixaService.abrirCaixa(
        valorInicial: parseValorReais(_valorController.text)!,
        staffUid: widget.staffAtual.uid,
        staffNome: widget.staffAtual.nome,
      );
      if (mounted) Navigator.of(context).pop();
    } on CaixaServiceException catch (e) {
      setState(() => _erro = e.message);
    } catch (_) {
      setState(() => _erro = 'Erro ao abrir o caixa. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Abrir caixa'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor inicial (R\$)',
              ),
              validator: (value) => parseValorReais(value ?? '') == null
                  ? 'Informe um valor válido.'
                  : null,
            ),
            if (_erro != null) ...[
              const SizedBox(height: 8),
              Text(
                _erro!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
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
          child: const Text('ABRIR'),
        ),
      ],
    );
  }
}

class _MovimentacaoDialog extends StatefulWidget {
  const _MovimentacaoDialog({
    required this.caixaService,
    required this.staffAtual,
    required this.caixaId,
    required this.tipo,
  });

  final CaixaService caixaService;
  final AppUser staffAtual;
  final String caixaId;
  final TipoMovimentacaoCaixa tipo;

  @override
  State<_MovimentacaoDialog> createState() => _MovimentacaoDialogState();
}

class _MovimentacaoDialogState extends State<_MovimentacaoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _valorController = TextEditingController();
  final _descricaoController = TextEditingController();
  bool _isSaving = false;
  String? _erro;

  @override
  void dispose() {
    _valorController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _confirmar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _erro = null;
    });
    try {
      await widget.caixaService.registrarMovimentacao(
        widget.caixaId,
        tipo: widget.tipo,
        valor: parseValorReais(_valorController.text)!,
        descricao: _descricaoController.text.trim().isEmpty
            ? null
            : _descricaoController.text.trim(),
        staffUid: widget.staffAtual.uid,
        staffNome: widget.staffAtual.nome,
      );
      if (mounted) Navigator.of(context).pop();
    } on CaixaServiceException catch (e) {
      setState(() => _erro = e.message);
    } catch (_) {
      setState(() => _erro = 'Erro ao registrar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = widget.tipo == TipoMovimentacaoCaixa.retirada
        ? 'Retirada'
        : 'Suprimento';
    return AlertDialog(
      title: Text(titulo),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _valorController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Valor (R\$)'),
              validator: (value) {
                final valor = parseValorReais(value ?? '');
                if (valor == null) return 'Informe um valor válido.';
                if (valor <= 0) return 'O valor deve ser maior que zero.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descricaoController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descrição (opcional)',
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 8),
              Text(
                _erro!,
                style: const TextStyle(color: AppColors.error, fontSize: 12),
              ),
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

class _HistoricoCaixasScreen extends StatelessWidget {
  const _HistoricoCaixasScreen({required this.caixaService});

  final CaixaService caixaService;

  String _formatarDataHora(DateTime? data) {
    if (data == null) return '—';
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year} '
        '${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de caixas')),
      body: StreamBuilder<List<Caixa>>(
        stream: caixaService.watchHistorico(),
        builder: (context, snapshot) {
          final caixas = snapshot.data ?? [];
          if (caixas.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum caixa no histórico ainda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: caixas.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final caixa = caixas[index];
              final cor = caixa.status == StatusCaixa.aberto
                  ? _corAberto
                  : (caixa.diferenca == null || caixa.diferenca == 0
                        ? AppColors.textSecondary
                        : AppColors.gold);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cor.withValues(alpha: 0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          caixa.status.label,
                          style: TextStyle(
                            color: cor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatarDataHora(caixa.abertoEm),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Aberto por ${caixa.abertoPorNome} · Inicial: ${formatarReais(caixa.valorInicial)}',
                    ),
                    if (caixa.status == StatusCaixa.fechado) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Fechado por ${caixa.fechadoPorNome ?? '—'} em '
                        '${_formatarDataHora(caixa.fechadoEm)}',
                      ),
                      Text(
                        'Esperado: ${formatarReais(caixa.valorEsperadoNoFechamento ?? 0)} · '
                        'Contado: ${formatarReais(caixa.valorContado ?? 0)} · '
                        'Diferença: ${formatarReais(caixa.diferenca ?? 0)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
