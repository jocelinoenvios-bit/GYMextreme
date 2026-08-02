import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/cargo.dart';
import '../../models/permission.dart';
import '../../services/cargo_service.dart';
import '../../services/funcionario_service.dart';
import '../../theme/app_colors.dart';

/// Cadastro de um novo funcionario (escolhe um cargo, que pre-marca as
/// permissoes padrao) ou edicao das permissoes individuais de um
/// funcionario existente (passe [funcionario] para entrar no modo edicao).
class FuncionarioFormScreen extends StatefulWidget {
  const FuncionarioFormScreen({
    super.key,
    required this.funcionarioService,
    required this.cargoService,
    this.funcionario,
  });

  final FuncionarioService funcionarioService;
  final CargoService cargoService;
  final AppUser? funcionario;

  @override
  State<FuncionarioFormScreen> createState() => _FuncionarioFormScreenState();
}

class _FuncionarioFormScreenState extends State<FuncionarioFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  Cargo? _cargoSelecionado;
  late Set<Permission> _permissoes;
  bool _isSaving = false;

  bool get _modoEdicao => widget.funcionario != null;

  @override
  void initState() {
    super.initState();
    _permissoes = {...widget.funcionario?.permissoes ?? const {}};
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  void _selecionarCargo(Cargo cargo) {
    setState(() {
      _cargoSelecionado = cargo;
      _permissoes = {...cargo.permissoesPadrao};
    });
  }

  Future<void> _handleSave() async {
    if (_modoEdicao) {
      setState(() => _isSaving = true);
      try {
        await widget.funcionarioService.atualizarPermissoes(
          widget.funcionario!.uid,
          _permissoes,
        );
        if (mounted) Navigator.of(context).pop();
      } catch (_) {
        _showError('Erro ao salvar as permissões. Tente novamente.');
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    if (_cargoSelecionado == null) {
      _showError('Selecione um cargo.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.funcionarioService.cadastrarFuncionario(
        nome: _nomeController.text,
        email: _emailController.text,
        senhaInicial: _senhaController.text,
        cargo: _cargoSelecionado!,
        permissoes: _permissoes,
      );
      if (mounted) Navigator.of(context).pop();
    } on FuncionarioServiceException catch (e) {
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
      appBar: AppBar(
        title: Text(_modoEdicao ? 'Permissões' : 'Novo funcionário'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (_modoEdicao) ...[
                Text(
                  widget.funcionario!.nome,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  widget.funcionario!.email,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 20),
              ] else ...[
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
                  decoration: const InputDecoration(labelText: 'Senha inicial'),
                  validator: (value) {
                    if (value == null || value.length < 6) {
                      return 'Mínimo de 6 caracteres.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                StreamBuilder<List<Cargo>>(
                  stream: widget.cargoService.watchCargos(),
                  builder: (context, snapshot) {
                    final cargos = snapshot.data ?? CargosPadrao.todos;
                    return DropdownButtonFormField<Cargo>(
                      initialValue: _cargoSelecionado,
                      decoration: const InputDecoration(labelText: 'Cargo'),
                      items: cargos
                          .map(
                            (cargo) => DropdownMenuItem(
                              value: cargo,
                              child: Text(cargo.nome),
                            ),
                          )
                          .toList(),
                      onChanged: (cargo) {
                        if (cargo != null) _selecionarCargo(cargo);
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
              Text('Permissões', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ...PermissaoCategoria.values.map(_buildCategoria),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleSave,
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.black),
                      )
                    : Text(_modoEdicao ? 'SALVAR PERMISSÕES' : 'CADASTRAR FUNCIONÁRIO'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoria(PermissaoCategoria categoria) {
    final permissoesDaCategoria = Permission.values
        .where((permission) => permission.categoria == categoria)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(categoria.label),
          initiallyExpanded: true,
          children: permissoesDaCategoria
              .map(
                (permission) => CheckboxListTile(
                  value: _permissoes.contains(permission),
                  title: Text(permission.label),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (marcado) {
                    setState(() {
                      if (marcado ?? false) {
                        _permissoes.add(permission);
                      } else {
                        _permissoes.remove(permission);
                      }
                    });
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
