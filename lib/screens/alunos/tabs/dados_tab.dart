import 'package:flutter/material.dart';

import '../../../models/aluno.dart';
import '../../../models/app_user.dart';
import '../../../services/aluno_service.dart';
import '../../../theme/app_colors.dart';

class DadosTab extends StatefulWidget {
  const DadosTab({super.key, required this.aluno, required this.alunoService});

  final AppUser aluno;
  final AlunoService alunoService;

  @override
  State<DadosTab> createState() => _DadosTabState();
}

class _DadosTabState extends State<DadosTab> {
  final _idadeController = TextEditingController();
  final _diaVencimentoController = TextEditingController();
  DateTime? _dataInicio;
  bool _isSaving = false;
  bool _isLoaded = false;

  @override
  void dispose() {
    _idadeController.dispose();
    _diaVencimentoController.dispose();
    super.dispose();
  }

  void _preencherSeNecessario(Aluno? aluno) {
    if (_isLoaded) return;
    _isLoaded = true;
    _idadeController.text = aluno?.idade?.toString() ?? '';
    _diaVencimentoController.text = aluno?.diaVencimento?.toString() ?? '';
    _dataInicio = aluno?.dataInicio;
  }

  Future<void> _pickDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data de início',
    );
    if (picked != null) setState(() => _dataInicio = picked);
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    try {
      await widget.alunoService.salvarDadosAluno(
        Aluno(
          uid: widget.aluno.uid,
          idade: int.tryParse(_idadeController.text),
          dataInicio: _dataInicio,
          diaVencimento: int.tryParse(_diaVencimentoController.text),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dados atualizados.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar. Tente novamente.'),
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
    return StreamBuilder<Aluno?>(
      stream: widget.alunoService.watchAluno(widget.aluno.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !_isLoaded) {
          return const Center(child: CircularProgressIndicator());
        }
        _preencherSeNecessario(snapshot.data);

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _ReadOnlyField(label: 'Nome', value: widget.aluno.nome),
            const SizedBox(height: 14),
            _ReadOnlyField(label: 'E-mail', value: widget.aluno.email),
            const SizedBox(height: 14),
            TextField(
              controller: _idadeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Idade'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _diaVencimentoController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Dia pago',
                helperText: 'Dia do mês (1-31)',
              ),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _pickDataInicio,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Data de início',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  _dataInicio == null
                      ? 'Não informada'
                      : '${_dataInicio!.day.toString().padLeft(2, '0')}/'
                            '${_dataInicio!.month.toString().padLeft(2, '0')}/'
                            '${_dataInicio!.year}',
                ),
              ),
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
                  : const Text('SALVAR'),
            ),
          ],
        );
      },
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
        ],
      ),
    );
  }
}
