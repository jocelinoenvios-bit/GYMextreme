import 'package:flutter/material.dart';

import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';

/// Cadastro de um novo aluno: cria o login (Firebase Auth) e os dados
/// basicos da ficha (idade, inicio, dia de vencimento). Anamnese, termo
/// e avaliacao fisica sao preenchidos depois, na ficha do aluno.
class AlunoFormScreen extends StatefulWidget {
  const AlunoFormScreen({super.key, required this.alunoService});

  final AlunoService alunoService;

  @override
  State<AlunoFormScreen> createState() => _AlunoFormScreenState();
}

class _AlunoFormScreenState extends State<AlunoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  final _idadeController = TextEditingController();
  final _diaVencimentoController = TextEditingController();

  DateTime _dataInicio = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    _idadeController.dispose();
    _diaVencimentoController.dispose();
    super.dispose();
  }

  Future<void> _pickDataInicio() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataInicio,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: 'Data de início',
    );
    if (picked != null) setState(() => _dataInicio = picked);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await widget.alunoService.cadastrarAluno(
        nome: _nomeController.text,
        email: _emailController.text,
        senhaInicial: _senhaController.text,
        idade: int.tryParse(_idadeController.text),
        dataInicio: _dataInicio,
        diaVencimento: int.tryParse(_diaVencimentoController.text),
      );
      if (mounted) Navigator.of(context).pop();
    } on AlunoServiceException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Erro inesperado ao cadastrar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Novo aluno')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nomeController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome completo'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Informe o nome.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Informe o e-mail.';
                  if (!value.contains('@') || !value.contains('.')) {
                    return 'Informe um e-mail válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha inicial',
                  helperText: 'O aluno pode trocar depois em "Esqueci minha senha".',
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Mínimo de 6 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _idadeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Idade'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _diaVencimentoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Dia pago',
                        helperText: 'Dia do mês (1-31)',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final dia = int.tryParse(value);
                        if (dia == null || dia < 1 || dia > 31) return 'Dia inválido.';
                        return null;
                      },
                    ),
                  ),
                ],
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
                    '${_dataInicio.day.toString().padLeft(2, '0')}/'
                    '${_dataInicio.month.toString().padLeft(2, '0')}/'
                    '${_dataInicio.year}',
                  ),
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                      )
                    : const Text('CADASTRAR ALUNO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
