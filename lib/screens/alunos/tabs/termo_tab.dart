import 'package:flutter/material.dart';

import '../../../constants/regulamento.dart';
import '../../../models/app_user.dart';
import '../../../models/termo_aceite.dart';
import '../../../services/aluno_service.dart';
import '../../../theme/app_colors.dart';

/// Replica o "REGULAMENTO" / Termo de Responsabilidade em papel, com
/// aceite digital no lugar da assinatura manuscrita.
class TermoTab extends StatefulWidget {
  const TermoTab({
    super.key,
    required this.aluno,
    required this.alunoService,
    required this.staffAtual,
  });

  final AppUser aluno;
  final AlunoService alunoService;

  /// Funcionario da recepcao logado, registrado no aceite (diferente de
  /// quem assina — aluno ou responsavel).
  final AppUser staffAtual;

  @override
  State<TermoTab> createState() => _TermoTabState();
}

class _TermoTabState extends State<TermoTab> {
  final _nomeController = TextEditingController();
  final _responsavelController = TextEditingController();
  bool _declaraCiencia = false;
  bool _isSaving = false;
  bool _nomePreenchido = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _responsavelController.dispose();
    super.dispose();
  }

  Future<void> _handleAceitar() async {
    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o nome de quem está assinando.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.alunoService.salvarTermoAceite(
        widget.aluno.uid,
        TermoAceite(
          aceito: true,
          nomeAssinatura: _nomeController.text.trim(),
          responsavel: _responsavelController.text.trim().isEmpty
              ? null
              : _responsavelController.text.trim(),
          versaoRegulamento: regulamentoVersaoAtual,
          registradoPorUid: widget.staffAtual.uid,
          registradoPorNome: widget.staffAtual.nome,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao registrar o aceite. Tente novamente.'),
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
    return StreamBuilder<TermoAceite>(
      stream: widget.alunoService.watchTermoAceite(widget.aluno.uid),
      builder: (context, snapshot) {
        final termo = snapshot.data;

        if (!_nomePreenchido) {
          _nomePreenchido = true;
          _nomeController.text = termo?.nomeAssinatura ?? widget.aluno.nome;
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const Text(
              'REGULAMENTO',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(regulamentoRegras.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: AppColors.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: '${(index + 1).toString().padLeft(2, '0')}. ',
                        style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: regulamentoRegras[index]),
                    ],
                  ),
                ),
              );
            }),
            const Divider(height: 32, color: AppColors.surfaceHigh),

            if (termo != null && termo.aceito)
              _AceiteConfirmado(termo: termo)
            else
              _AceiteForm(
                nomeController: _nomeController,
                responsavelController: _responsavelController,
                declaraCiencia: _declaraCiencia,
                isSaving: _isSaving,
                onDeclaraCienciaChanged: (v) => setState(() => _declaraCiencia = v ?? false),
                onSubmit: (_declaraCiencia && !_isSaving) ? _handleAceitar : null,
              ),
          ],
        );
      },
    );
  }
}

class _AceiteConfirmado extends StatelessWidget {
  const _AceiteConfirmado({required this.termo});

  final TermoAceite termo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, color: AppColors.gold),
              SizedBox(width: 8),
              Text(
                'Termo aceito',
                style: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Assinatura: ${termo.nomeAssinatura ?? '-'}',
              style: const TextStyle(color: AppColors.textPrimary)),
          if (termo.responsavel != null && termo.responsavel!.isNotEmpty)
            Text('Responsável: ${termo.responsavel}',
                style: const TextStyle(color: AppColors.textPrimary)),
          if (termo.aceitoEm != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Aceito em ${_formatarDataHora(termo.aceitoEm!)}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }

  String _formatarDataHora(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes/${data.year} às $hora:$minuto';
  }
}

class _AceiteForm extends StatelessWidget {
  const _AceiteForm({
    required this.nomeController,
    required this.responsavelController,
    required this.declaraCiencia,
    required this.isSaving,
    required this.onDeclaraCienciaChanged,
    required this.onSubmit,
  });

  final TextEditingController nomeController;
  final TextEditingController responsavelController;
  final bool declaraCiencia;
  final bool isSaving;
  final ValueChanged<bool?> onDeclaraCienciaChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DECLARO ACEITAR AS NORMAS DESTE REGULAMENTO',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: nomeController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Assinatura (nome completo)'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: responsavelController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Responsável',
            helperText: 'Preencher apenas se o aluno for menor de idade',
          ),
        ),
        const SizedBox(height: 14),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: declaraCiencia,
          onChanged: onDeclaraCienciaChanged,
          title: const Text(
            'Li e aceito as normas deste regulamento (Termo de Responsabilidade).',
            style: TextStyle(fontSize: 13.5),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: onSubmit,
          child: isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                )
              : const Text('ACEITAR E ASSINAR'),
        ),
      ],
    );
  }
}
