import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/caixa.dart';
import '../../services/caixa_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';

/// Fecha o caixa: mostra o saldo esperado (calculado no momento em que
/// esta tela foi aberta — `saldoEsperadoAtual`, vindo de `CaixaScreen`),
/// pede o valor contado e calcula a diferença em tempo real antes de
/// confirmar. Depois de confirmado, o caixa não é mais alterado por
/// nenhuma tela deste módulo (ver `CaixaService.fecharCaixa`).
class FecharCaixaScreen extends StatefulWidget {
  const FecharCaixaScreen({
    super.key,
    required this.caixaService,
    required this.staffAtual,
    required this.caixa,
    required this.saldoEsperadoAtual,
  });

  final CaixaService caixaService;
  final AppUser staffAtual;
  final Caixa caixa;
  final double saldoEsperadoAtual;

  @override
  State<FecharCaixaScreen> createState() => _FecharCaixaScreenState();
}

class _FecharCaixaScreenState extends State<FecharCaixaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _valorContadoController = TextEditingController();
  final _observacaoController = TextEditingController();
  bool _isSaving = false;

  double? get _valorContado => parseValorReais(_valorContadoController.text);
  double? get _diferenca =>
      _valorContado == null ? null : _valorContado! - widget.saldoEsperadoAtual;

  @override
  void dispose() {
    _valorContadoController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  Future<void> _handleFechar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await widget.caixaService.fecharCaixa(
        widget.caixa.id!,
        valorContado: _valorContado!,
        observacao: _observacaoController.text.trim().isEmpty
            ? null
            : _observacaoController.text.trim(),
        staffUid: widget.staffAtual.uid,
        staffNome: widget.staffAtual.nome,
      );
      if (mounted) Navigator.of(context).pop();
    } on CaixaServiceException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Erro ao fechar o caixa. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Color _corDiferenca(double diferenca) {
    if (diferenca == 0) return AppColors.textSecondary;
    return diferenca > 0 ? const Color(0xFF4CAF6D) : AppColors.error;
  }

  String _rotuloDiferenca(double diferenca) {
    if (diferenca == 0) return 'Sem diferença';
    return diferenca > 0 ? 'Sobra' : 'Falta';
  }

  @override
  Widget build(BuildContext context) {
    final diferenca = _diferenca;
    return Scaffold(
      appBar: AppBar(title: const Text('Fechar caixa')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Saldo esperado: ${formatarReais(widget.saldoEsperadoAtual)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calculado a partir do valor inicial + todas as '
                  'movimentações registradas até agora.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _valorContadoController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Valor contado (R\$)',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (value) => parseValorReais(value ?? '') == null
                      ? 'Informe um valor válido.'
                      : null,
                ),
                const SizedBox(height: 14),
                if (diferenca != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _corDiferenca(diferenca).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _rotuloDiferenca(diferenca),
                          style: TextStyle(
                            color: _corDiferenca(diferenca),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          formatarReais(diferenca),
                          style: TextStyle(
                            color: _corDiferenca(diferenca),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _observacaoController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Observação (opcional)',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _handleFechar,
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.black,
                          ),
                        )
                      : const Text('CONFIRMAR FECHAMENTO'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
