import 'package:flutter/material.dart';

import '../../models/treino.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import 'treino_execucao_screen.dart';

/// Lista dos treinos do próprio aluno — só visualização e execução, sem
/// criar/editar/excluir (isso é tarefa do personal, em [TreinosTab]).
/// Reaproveita [AlunoService.watchTreinos] e a [TreinoExecucaoScreen] já
/// usadas do lado do staff.
class MeusTreinosScreen extends StatelessWidget {
  const MeusTreinosScreen({super.key, required this.uid, required this.alunoService});

  final String uid;
  final AlunoService alunoService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus treinos')),
      body: StreamBuilder<List<Treino>>(
        stream: alunoService.watchTreinos(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Erro ao carregar seus treinos.',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            );
          }

          final treinos = (snapshot.data ?? []).where((treino) => treino.ativo).toList();
          if (treinos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhum treino prescrito ainda. Fale com seu personal.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: treinos.length,
            itemBuilder: (context, index) => _TreinoTile(
              treino: treinos[index],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => TreinoExecucaoScreen(alunoUid: uid, treinoId: treinos[index].id!),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TreinoTile extends StatelessWidget {
  const _TreinoTile({required this.treino, required this.onTap});

  final Treino treino;
  final VoidCallback onTap;

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
        trailing: const Icon(Icons.play_circle_outline, color: AppColors.gold),
      ),
    );
  }
}
