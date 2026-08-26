import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/permission.dart';
import '../../models/plano.dart';
import '../../services/permission_service.dart';
import '../../services/plano_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/moeda.dart';
import 'plano_form_screen.dart';

/// Lista administrativa de planos de mensalidade da academia — cadastrar,
/// editar e inativar. Ponto de entrada pra escolher um plano ao criar uma
/// matrícula nova.
class PlanosListScreen extends StatelessWidget {
  const PlanosListScreen({super.key, required this.planoService, required this.staffAtual});

  final PlanoService planoService;
  final AppUser staffAtual;

  bool get _podeCadastrar => PermissionService.has(staffAtual, Permission.cadastrarPlanos);
  bool get _podeAlterar => PermissionService.has(staffAtual, Permission.alterarPlanos);
  bool get _podeExcluir => PermissionService.has(staffAtual, Permission.excluirPlanos);

  void _abrirFormulario(BuildContext context, {Plano? plano}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanoFormScreen(planoService: planoService, plano: plano),
      ),
    );
  }

  Future<void> _confirmarExclusao(BuildContext context, Plano plano) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir plano'),
        content: Text(
          'O plano "${plano.nome}" deixa de aparecer pra novas matrículas. '
          'Matrículas já contratadas com este plano não são afetadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('EXCLUIR'),
          ),
        ],
      ),
    );
    if (confirmou == true) {
      await planoService.excluirPlano(plano.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Planos')),
      floatingActionButton: _podeCadastrar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirFormulario(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo plano'),
            )
          : null,
      body: StreamBuilder<List<Plano>>(
        stream: planoService.watchPlanos(),
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
                    'Erro ao carregar os planos.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ),
            );
          }

          final planos = snapshot.data ?? [];
          if (planos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _podeCadastrar
                      ? 'Nenhum plano cadastrado ainda. Toque em "+" para criar o primeiro.'
                      : 'Nenhum plano cadastrado ainda.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: planos.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final plano = planos[index];
              return _PlanoCard(
                plano: plano,
                podeAlterar: _podeAlterar,
                podeExcluir: _podeExcluir,
                onTap: _podeAlterar ? () => _abrirFormulario(context, plano: plano) : null,
                onExcluir: () => _confirmarExclusao(context, plano),
              );
            },
          );
        },
      ),
    );
  }
}

class _PlanoCard extends StatelessWidget {
  const _PlanoCard({
    required this.plano,
    required this.podeAlterar,
    required this.podeExcluir,
    required this.onTap,
    required this.onExcluir,
  });

  final Plano plano;
  final bool podeAlterar;
  final bool podeExcluir;
  final VoidCallback? onTap;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(child: Text(plano.nome)),
            if (!plano.ativo)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Inativo',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${formatarReais(plano.valor)} · ${plano.duracaoDias} dias'
          '${plano.descricao != null ? ' · ${plano.descricao}' : ''}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: podeExcluir
            ? IconButton(
                tooltip: 'Excluir plano',
                icon: const Icon(Icons.delete_outline, color: AppColors.textSecondary),
                onPressed: onExcluir,
              )
            : (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textSecondary) : null),
      ),
    );
  }
}
