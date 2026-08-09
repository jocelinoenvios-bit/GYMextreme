import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/conta_receber.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';

/// Registra o recebimento de uma cobrança — valor recebido, desconto,
/// juros/multa, forma de pagamento, data e observação. Não apaga nada: a
/// própria [ContaReceber] é atualizada (`status: pago`), o histórico
/// (quem lançou, quando) continua no mesmo documento.
class RegistrarRecebimentoScreen extends StatefulWidget {
  const RegistrarRecebimentoScreen({
    super.key,
    required this.alunoService,
    required this.staffAtual,
    required this.conta,
  });

  final AlunoService alunoService;
  final AppUser staffAtual;
  final ContaReceber conta;

  @override
  State<RegistrarRecebimentoScreen> createState() => _RegistrarRecebimentoScreenState();
}

class _RegistrarRecebimentoScreenState extends State<RegistrarRecebimentoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _valorPagoController = TextEditingController(
    text: formatarReais(widget.conta.valorLiquido).replaceFirst('R\$ ', ''),
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

  @override
  void dispose() {
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
      helpText: 'Data do recebimento',
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

    setState(() => _isSaving = true);
    try {
      await widget.alunoService.registrarRecebimento(
        widget.conta.alunoId,
        widget.conta.id!,
        valorPago: parseValorReais(_valorPagoController.text)!,
        desconto: parseValorReais(_descontoController.text) ?? 0,
        jurosMulta: parseValorReais(_jurosMultaController.text) ?? 0,
        dataPagamento: _dataPagamento,
        formaPagamento: _formaPagamentoController.text.trim().isEmpty
            ? null
            : _formaPagamentoController.text.trim(),
        observacao: _observacaoController.text.trim().isEmpty
            ? null
            : _observacaoController.text.trim(),
        staffUid: widget.staffAtual.uid,
        staffNome: widget.staffAtual.nome,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      _showError('Erro ao registrar o recebimento. Tente novamente.');
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
      appBar: AppBar(title: const Text('Registrar recebimento')),
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
                  'Vencimento: ${_formatarData(widget.conta.vencimento)} · '
                  'Valor esperado: ${formatarReais(widget.conta.valorLiquido)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _valorPagoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Valor recebido (R\$)'),
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
                  title: const Text('Data do recebimento'),
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
                      : const Text('CONFIRMAR RECEBIMENTO'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
