import 'package:flutter/material.dart';

import '../../constants/circunferencia_fields.dart';
import '../../models/avaliacao_fisica.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/imc.dart';

/// Uma nova entrada de avaliacao fisica, com as mesmas medidas
/// antropometricas e circunferencias da ficha em papel.
class AvaliacaoFisicaFormScreen extends StatefulWidget {
  const AvaliacaoFisicaFormScreen({
    super.key,
    required this.uid,
    required this.alunoService,
  });

  final String uid;
  final AlunoService alunoService;

  @override
  State<AvaliacaoFisicaFormScreen> createState() => _AvaliacaoFisicaFormScreenState();
}

class _AvaliacaoFisicaFormScreenState extends State<AvaliacaoFisicaFormScreen> {
  DateTime _data = DateTime.now();
  final _pesoController = TextEditingController();
  final _alturaController = TextEditingController();
  final _observacoesController = TextEditingController();
  final Map<String, TextEditingController> _circunferenciaControllers = {
    for (final field in circunferenciaFields) field.key: TextEditingController(),
  };

  bool _isSaving = false;

  @override
  void dispose() {
    _pesoController.dispose();
    _alturaController.dispose();
    _observacoesController.dispose();
    for (final controller in _circunferenciaControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickData() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data da avaliação',
    );
    if (picked != null) setState(() => _data = picked);
  }

  double? _parse(String text) => double.tryParse(text.replaceAll(',', '.'));

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      await widget.alunoService.adicionarAvaliacao(
        widget.uid,
        AvaliacaoFisica(
          data: _data,
          pesoKg: _parse(_pesoController.text),
          alturaM: _parse(_alturaController.text),
          circunferenciasCm: _circunferenciaControllers.map(
            (key, controller) => MapEntry(key, _parse(controller.text)),
          ),
          observacoes: _observacoesController.text.trim().isEmpty
              ? null
              : _observacoesController.text.trim(),
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar a avaliação. Tente novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peso = _parse(_pesoController.text);
    final altura = _parse(_alturaController.text);
    final imc = calcularImc(pesoKg: peso, alturaM: altura);

    return Scaffold(
      appBar: AppBar(title: const Text('Nova avaliação física')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            InkWell(
              onTap: _pickData,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data da avaliação',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  '${_data.day.toString().padLeft(2, '0')}/'
                  '${_data.month.toString().padLeft(2, '0')}/${_data.year}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            const _SecaoTitulo('Medidas antropométricas'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pesoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Peso (Kg)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _alturaController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Altura (m)'),
                  ),
                ),
              ],
            ),
            if (imc != null) ...[
              const SizedBox(height: 12),
              _ImcBadge(imc: imc),
            ],
            const SizedBox(height: 20),
            const _SecaoTitulo('Circunferências (cm)'),
            ...circunferenciaFields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: _circunferenciaControllers[field.key],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: field.label),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _observacoesController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Observações'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                    )
                  : const Text('SALVAR AVALIAÇÃO'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecaoTitulo extends StatelessWidget {
  const _SecaoTitulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        texto,
        style: const TextStyle(
          color: AppColors.gold,
          fontWeight: FontWeight.bold,
          fontSize: 13,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _ImcBadge extends StatelessWidget {
  const _ImcBadge({required this.imc});

  final double imc;

  @override
  Widget build(BuildContext context) {
    final classificacao = classificarImc(imc);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: classificacao.cor.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(
            color: classificacao.cor,
            shape: BoxShape.circle,
          )),
          const SizedBox(width: 10),
          Text(
            'IMC ${imc.toStringAsFixed(1)} · ${classificacao.rotulo}',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
