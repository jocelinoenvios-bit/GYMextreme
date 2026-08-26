import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/caixa.dart';
import '../../models/conta_pagar.dart';
import '../../services/caixa_service.dart';
import '../../services/conta_pagar_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';

/// Registra o pagamento de uma despesa — valor pago, desconto, juros/multa,
/// forma de pagamento, data e observação. Não apaga nada: a própria
/// [ContaPagar] é atualizada (`status: pago`), o histórico continua no
/// mesmo documento.
///
/// Integração com o Caixa: se houver um caixa aberto no momento (ver
/// `CaixaService.watchCaixaAberto`), o pagamento também é lançado como uma
/// saída nesse caixa, atomicamente
/// (`CaixaService.registrarPagamentoContaPagar`). Sem caixa aberto, o
/// pagamento segue por `ContaPagarService.registrarPagamentoSemCaixa`,
/// sem depender do módulo de caixa pra nada — mesmo padrão de
/// `RegistrarRecebimentoScreen`.
class RegistrarPagamentoScreen extends StatefulWidget {
  const RegistrarPagamentoScreen({
    super.key,
    required this.contaPagarService,
    required this.caixaService,
    required this.staffAtual,
    required this.conta,
  });

  final ContaPagarService contaPagarService;
  final CaixaService caixaService;
  final AppUser staffAtual;
  final ContaPagar conta;

  @override
  State<RegistrarPagamentoScreen> createState() => _RegistrarPagamentoScreenState();
}

class _RegistrarPagamentoScreenState extends State<RegistrarPagamentoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _valorPagoController = TextEditingController(
    text: formatarReais(widget.conta.valorFinal).replaceFirst('R\$ ', ''),
  );
  late final _descontoController = TextEditingController(
    text: formatarReais(widget.conta.desconto).replaceFirst('R\$ ', ''),
  );
  late final _jurosMultaController = TextEditingController(
    text: formatarReais(widget.conta.jurosMulta).replaceFirst('R\$ ', ''),
  );
  late final _formaPagamentoController = TextEditingController(
    text: widget.conta.formaPagamento,
  );
  late final _observacaoController = TextEditingController(text: widget.conta.observacao);

  DateTime _dataPagamento = DateTime.now();
  bool _isSaving = false;

  Caixa? _caixaAberto;
  StreamSubscription<Caixa?>? _caixaSubscription;

  @override
  void initState() {
    super.initState();
    _caixaSubscription = widget.caixaService.watchCaixaAberto().listen((caixa) {
      if (mounted) setState(() => _caixaAberto = caixa);
    });
  }

  @override
  void dispose() {
    _caixaSubscription?.cancel();
    _valorPagoController.dispose();
    _descontoController.dispose();
    _jurosMultaController.dispose();
    _formaPagamentoController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _escolherData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataPagamento,
      firstDate: DateTime(_dataPagamento.year - 1),
      lastDate: DateTime(_dataPagamento.year + 1),
      helpText: 'Data do pagamento',
    );
    if (picked == null) return;
    setState(() => _dataPagamento = picked);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleConfirmar() async {
    if (!_formKey.currentState!.validate()) return;

    final valorPago = parseValorReais(_valorPagoController.text)!;
    final desconto = parseValorReais(_descontoController.text) ?? 0;
    final jurosMulta = parseValorReais(_jurosMultaController.text) ?? 0;
    final formaPagamento = _formaPagamentoController.text.trim().isEmpty
        ? null
        : _formaPagamentoController.text.trim();
    final observacao = _observacaoController.text.trim().isEmpty
        ? null
        : _observacaoController.text.trim();
    final caixaAberto = _caixaAberto;

    setState(() => _isSaving = true);
    try {
      if (caixaAberto != null) {
        await widget.caixaService.registrarPagamentoContaPagar(
          caixaId: caixaAberto.id!,
          contaPagarId: widget.conta.id!,
          valorPago: valorPago,
          desconto: desconto,
          jurosMulta: jurosMulta,
          dataPagamento: _dataPagamento,
          formaPagamento: formaPagamento,
          observacao: observacao,
          staffUid: widget.staffAtual.uid,
          staffNome: widget.staffAtual.nome,
        );
      } else {
        await widget.contaPagarService.registrarPagamentoSemCaixa(
          widget.conta.id!,
          valorPago: valorPago,
          desconto: desconto,
          jurosMulta: jurosMulta,
          dataPagamento: _dataPagamento,
          formaPagamento: formaPagamento,
          observacao: observacao,
          staffUid: widget.staffAtual.uid,
          staffNome: widget.staffAtual.nome,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on CaixaServiceException catch (e) {
      _showError(e.message);
    } on ContaPagarServiceException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Erro ao registrar o pagamento. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar pagamento')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.conta.descricao, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${widget.conta.fornecedor} · '
                  'Vencimento: ${_formatarData(widget.conta.vencimento)} · '
                  'Valor esperado: ${formatarReais(widget.conta.valorFinal)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  _caixaAberto != null
                      ? 'Caixa aberto — este pagamento também será lançado como '
                            'saída no caixa.'
                      : 'Nenhum caixa aberto — este pagamento não gera nenhuma '
                            'movimentação de caixa.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _valorPagoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor pago (R\$)'),
                  validator: (value) {
                    final valor = parseValorReais(value ?? '');
                    if (valor == null) return 'Informe um valor válido.';
                    if (valor <= 0) return 'O valor deve ser maior que zero.';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _descontoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Desconto (R\$)'),
                        validator: (value) =>
                            parseValorReais(value ?? '0') == null ? 'Valor inválido.' : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _jurosMultaController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Juros/multa (R\$)'),
                        validator: (value) =>
                            parseValorReais(value ?? '0') == null ? 'Valor inválido.' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Data do pagamento'),
                  subtitle: Text(_formatarData(_dataPagamento)),
                  trailing: const Icon(Icons.calendar_today_outlined, color: AppColors.gold),
                  onTap: _escolherData,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _formaPagamentoController,
                  decoration: const InputDecoration(labelText: 'Forma de pagamento'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe a forma de pagamento.'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _observacaoController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observação (opcional)'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleConfirmar,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.black,
                          ),
                        )
                      : const Text('CONFIRMAR PAGAMENTO'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
