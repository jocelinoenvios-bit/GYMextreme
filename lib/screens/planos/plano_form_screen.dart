import 'package:flutter/material.dart';

import '../../models/plano.dart';
import '../../services/plano_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';

/// Cadastro de um novo plano ou edição de um existente (passe [plano] para
/// entrar no modo edição).
class PlanoFormScreen extends StatefulWidget {
  const PlanoFormScreen({super.key, required this.planoService, this.plano});

  final PlanoService planoService;
  final Plano? plano;

  @override
  State<PlanoFormScreen> createState() => _PlanoFormScreenState();
}

class _PlanoFormScreenState extends State<PlanoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nomeController = TextEditingController(text: widget.plano?.nome);
  late final _descricaoController = TextEditingController(text: widget.plano?.descricao);
  late final _valorController = TextEditingController(
    text: widget.plano != null ? formatarReais(widget.plano!.valor).replaceFirst('R\$ ', '') : null,
  );
  late final _duracaoController = TextEditingController(
    text: widget.plano?.duracaoDias.toString(),
  );

  bool _ativo = true;
  bool _isSaving = false;

  bool get _modoEdicao => widget.plano != null;

  @override
  void initState() {
    super.initState();
    _ativo = widget.plano?.ativo ?? true;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    _valorController.dispose();
    _duracaoController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await widget.planoService.salvarPlano(
        Plano(
          id: widget.plano?.id,
          nome: _nomeController.text.trim(),
          descricao: _descricaoController.text.trim().isEmpty
              ? null
              : _descricaoController.text.trim(),
          valor: parseValorReais(_valorController.text)!,
          duracaoDias: int.parse(_duracaoController.text.trim()),
          ativo: _ativo,
          criadoEm: widget.plano?.criadoEm,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao salvar o plano. Tente novamente.'),
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
    return Scaffold(
      appBar: AppBar(title: Text(_modoEdicao ? 'Editar plano' : 'Novo plano')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _nomeController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Informe o nome.' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descricaoController,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Descrição (opcional)'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _valorController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                validator: (value) {
                  final valor = parseValorReais(value ?? '');
                  if (valor == null) return 'Informe um valor válido.';
                  if (valor <= 0) return 'O valor deve ser maior que zero.';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _duracaoController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Duração (dias)',
                  helperText: 'Ex.: 30 = mensal, 90 = trimestral, 365 = anual',
                ),
                validator: (value) {
                  final duracao = int.tryParse((value ?? '').trim());
                  if (duracao == null || duracao <= 0) {
                    return 'Informe a duração em dias corridos.';
                  }
                  return null;
                },
              ),
              if (_modoEdicao) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Plano ativo'),
                  subtitle: const Text(
                    'Planos inativos somem da lista de novas matrículas, sem '
                    'afetar matrículas já contratadas.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                  value: _ativo,
                  onChanged: (valor) => setState(() => _ativo = valor),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                      )
                    : Text(_modoEdicao ? 'SALVAR ALTERAÇÕES' : 'CADASTRAR PLANO'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
