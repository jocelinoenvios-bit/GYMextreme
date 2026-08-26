import 'package:flutter/material.dart';

import '../../../models/app_user.dart';
import '../../../models/permission.dart';
import '../../../models/treino.dart';
import '../../../services/aluno_service.dart';
import '../../../services/permission_service.dart';
import '../../../theme/app_colors.dart';
import '../../area_aluno/treino_execucao_screen.dart';
import '../treino_form_screen.dart';
import '../copiar_treino_dialog.dart';

/// Fichas de treino do aluno (Treino A, B, C...) — cada card abre pra
/// editar; o professor cria, edita, exclui ou duplica um treino, copia
/// um treino ja pronto de outro aluno, ou executa o treino (mesmo fluxo
/// real que o aluno usa, útil pra revisar antes de liberar).
class TreinosTab extends StatelessWidget {
  const TreinosTab({
    super.key,
    required this.uid,
    required this.alunoService,
    required this.staffAtual,
  });

  final String uid;
  final AlunoService alunoService;
  final AppUser staffAtual;

  bool get _podeCriar => PermissionService.has(staffAtual, Permission.criarTreinos);
  bool get _podeEditar => PermissionService.has(staffAtual, Permission.editarTreinos);

  void _abrirNovoTreino(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TreinoFormScreen(
          alunoUid: uid,
          alunoService: alunoService,
          staffAtual: staffAtual,
        ),
      ),
    );
  }

  void _abrirCopiarTreino(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CopiarTreinoDialog(
        alunoDestinoUid: uid,
        alunoService: alunoService,
        staffAtual: staffAtual,
      ),
    );
  }

  void _abrirMenuNovo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add, color: AppColors.gold),
              title: const Text('Criar treino novo'),
              onTap: () {
                Navigator.of(context).pop();
                _abrirNovoTreino(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_all_outlined, color: AppColors.gold),
              title: const Text('Copiar treino de outro aluno'),
              onTap: () {
                Navigator.of(context).pop();
                _abrirCopiarTreino(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _podeCriar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirMenuNovo(context),
              icon: const Icon(Icons.add),
              label: const Text('Novo treino'),
            )
          : null,
      body: StreamBuilder<List<Treino>>(
        stream: alunoService.watchTreinos(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Erro ao carregar os treinos.',
                style: TextStyle(color: AppColors.error),
              ),
            );
          }

          final treinos = snapshot.data ?? [];
          if (treinos.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _podeCriar
                      ? 'Nenhum treino cadastrado ainda. Toque em "+" para criar o primeiro.'
                      : 'Nenhum treino cadastrado ainda.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: treinos.length,
            itemBuilder: (context, index) => _TreinoCard(
              treino: treinos[index],
              podeEditar: _podeEditar,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TreinoFormScreen(
                    alunoUid: uid,
                    alunoService: alunoService,
                    staffAtual: staffAtual,
                    treino: treinos[index],
                  ),
                ),
              ),
              onExecutar: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TreinoExecucaoScreen(
                    alunoUid: uid,
                    treinoId: treinos[index].id!,
                  ),
                ),
              ),
              onDuplicar: () => alunoService.duplicarTreino(
                uid,
                treinos[index],
                staffUid: staffAtual.uid,
                staffNome: staffAtual.nome,
              ),
              onExcluir: () => alunoService.excluirTreino(uid, treinos[index].id!),
            ),
          );
        },
      ),
    );
  }
}

class _TreinoCard extends StatelessWidget {
  const _TreinoCard({
    required this.treino,
    required this.podeEditar,
    required this.onTap,
    required this.onExecutar,
    required this.onDuplicar,
    required this.onExcluir,
  });

  final Treino treino;
  final bool podeEditar;
  final VoidCallback onTap;
  final VoidCallback onExecutar;
  final VoidCallback onDuplicar;
  final VoidCallback onExcluir;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.gold,
          child: Text(
            treino.letra,
            style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(treino.nome),
        subtitle: Text(
          [
            if (treino.grupoMuscular != null && treino.grupoMuscular!.isNotEmpty)
              treino.grupoMuscular!,
            '${treino.exercicios.length} exercício(s)',
          ].join(' • '),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Executar treino',
              icon: const Icon(Icons.play_circle_outline, color: AppColors.gold),
              onPressed: onExecutar,
            ),
            if (podeEditar)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: (acao) {
                  if (acao == 'duplicar') onDuplicar();
                  if (acao == 'excluir') onExcluir();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
                  PopupMenuItem(value: 'excluir', child: Text('Excluir')),
                ],
              )
            else
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
