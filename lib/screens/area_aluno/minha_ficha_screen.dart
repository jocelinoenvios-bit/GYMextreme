import 'package:flutter/material.dart';

import '../../models/treino.dart';
import '../../services/aluno_service.dart';
import '../../services/exercise_repository.dart';
import '../../theme/app_colors.dart';
import 'historico_treinos_screen.dart';
import 'treino_detalhe_aluno_screen.dart';

/// Ficha de treinos do aluno organizada por dia da semana (segunda a
/// domingo) — sempre mostra o treino prescrito de cada dia, mesmo que
/// o aluno tenha faltado naquele dia (presença é uma informação
/// completamente separada, ver `HistoricoTreinosScreen`). Só treinos
/// ativos aparecem aqui; a letra "Semanas anteriores"/"Histórico" fica
/// no botão de baixo, que já filtra treinos inativos como fichas
/// antigas.
class MinhaFichaScreen extends StatelessWidget {
  const MinhaFichaScreen({
    super.key,
    required this.uid,
    required this.alunoService,
    this.repository = const LocalExerciseRepository(),
  });

  final String uid;
  final AlunoService alunoService;
  final ExerciseRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minha ficha')),
      body: SafeArea(
        child: StreamBuilder<List<Treino>>(
          stream: alunoService.watchTreinos(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final todos = (snapshot.data ?? []).where((t) => t.ativo).toList();
            if (todos.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Você ainda não possui uma ficha de treino cadastrada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            final comDia = todos.where((t) => t.diaSemana != null).toList();
            final semDia = todos.where((t) => t.diaSemana == null).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (var dia = 1; dia <= 7; dia++)
                  _DiaSection(
                    dia: dia,
                    treinos: comDia.where((t) => t.diaSemana == dia).toList(),
                    uid: uid,
                    repository: repository,
                  ),
                if (semDia.isNotEmpty)
                  _DiaSection(
                    dia: null,
                    treinos: semDia,
                    uid: uid,
                    repository: repository,
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          HistoricoTreinosScreen(uid: uid, alunoService: alunoService),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('HISTÓRICO DE TREINOS (SEMANAS ANTERIORES)'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DiaSection extends StatelessWidget {
  const _DiaSection({
    required this.dia,
    required this.treinos,
    required this.uid,
    required this.repository,
  });

  /// `null` = seção "sem dia definido".
  final int? dia;
  final List<Treino> treinos;
  final String uid;
  final ExerciseRepository repository;

  @override
  Widget build(BuildContext context) {
    final titulo = dia == null ? 'SEM DIA DEFINIDO' : diasSemanaLabels[dia!].toUpperCase();

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          if (treinos.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'Nenhum treino prescrito.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            )
          else
            for (final treino in treinos) _TreinoCard(treino: treino, uid: uid, repository: repository),
        ],
      ),
    );
  }
}

class _TreinoCard extends StatelessWidget {
  const _TreinoCard({required this.treino, required this.uid, required this.repository});

  final Treino treino;
  final String uid;
  final ExerciseRepository repository;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: ListTile(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TreinoDetalheAlunoScreen(
              alunoUid: uid,
              treino: treino,
              repository: repository,
            ),
          ),
        ),
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
        trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
      ),
    );
  }
}
