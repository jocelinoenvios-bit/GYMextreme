import 'package:flutter/material.dart';

import '../../models/exercise_model.dart';
import '../../models/treino.dart';
import '../../services/exercise_repository.dart';
import '../../theme/app_colors.dart';
import 'treino_execucao_screen.dart';

/// Ficha completa de UM treino prescrito, somente leitura — nome,
/// objetivo, dia da semana, exercícios com séries/repetições/carga/
/// descanso/observações na ordem certa, data em que foi prescrito e
/// validade, quando existir. Sempre disponível pro aluno consultar,
/// mesmo em dias que ele faltou (ver `MinhaFichaScreen`) — esta tela
/// nunca depende de registro de presença.
class TreinoDetalheAlunoScreen extends StatelessWidget {
  const TreinoDetalheAlunoScreen({
    super.key,
    required this.alunoUid,
    required this.treino,
    this.repository = const LocalExerciseRepository(),
  });

  final String alunoUid;
  final Treino treino;
  final ExerciseRepository repository;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Treino ${treino.letra}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              treino.nome,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (treino.grupoMuscular != null && treino.grupoMuscular!.isNotEmpty)
                  _Badge(treino.grupoMuscular!),
                if (treino.objetivo != null && treino.objetivo!.isNotEmpty)
                  _Badge(treino.objetivo!),
                if (treino.diaSemana != null)
                  _Badge(diasSemanaLabels[treino.diaSemana!]),
                if (!treino.ativo) const _Badge('Ficha anterior', destaque: false),
              ],
            ),
            const SizedBox(height: 16),
            if (treino.criadoEm != null)
              _LinhaInfo('Prescrito em', _formatarData(treino.criadoEm!)),
            if (treino.vigenciaAte != null)
              _LinhaInfo('Válido até', _formatarData(treino.vigenciaAte!)),
            const SizedBox(height: 20),
            const Text(
              'Exercícios',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            if (treino.exercicios.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Este treino ainda não tem exercícios cadastrados.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              FutureBuilder<List<ExerciseModel>>(
                future: repository.buscarTodos(),
                builder: (context, snapshot) {
                  final biblioteca = {
                    for (final e in snapshot.data ?? <ExerciseModel>[]) e.id: e,
                  };
                  final exercicios = [...treino.exercicios]
                    ..sort((a, b) => a.ordem.compareTo(b.ordem));
                  return Column(
                    children: [
                      for (var i = 0; i < exercicios.length; i++)
                        _ExercicioTile(
                          numero: i + 1,
                          treinoExercicio: exercicios[i],
                          exercicio: biblioteca[exercicios[i].exercicioId],
                        ),
                    ],
                  );
                },
              ),
            const SizedBox(height: 24),
            if (treino.id != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TreinoExecucaoScreen(
                        alunoUid: alunoUid,
                        treinoId: treino.id!,
                        repository: repository,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('EXECUTAR TREINO'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.texto, {this.destaque = true});

  final String texto;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: destaque ? AppColors.gold.withValues(alpha: 0.15) : AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: destaque ? AppColors.goldBright : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LinhaInfo extends StatelessWidget {
  const _LinhaInfo(this.rotulo, this.valor);

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          children: [
            TextSpan(text: '$rotulo: '),
            TextSpan(
              text: valor,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExercicioTile extends StatelessWidget {
  const _ExercicioTile({
    required this.numero,
    required this.treinoExercicio,
    required this.exercicio,
  });

  final int numero;
  final TreinoExercicio treinoExercicio;
  final ExerciseModel? exercicio;

  @override
  Widget build(BuildContext context) {
    final resumo = [
      if (treinoExercicio.series != null) '${treinoExercicio.series} séries',
      if (treinoExercicio.repeticoes != null && treinoExercicio.repeticoes!.isNotEmpty)
        '${treinoExercicio.repeticoes} reps',
      if (treinoExercicio.cargaKg != null) '${treinoExercicio.cargaKg}kg',
      if (treinoExercicio.descansoSegundos != null)
        'descanso ${treinoExercicio.descansoSegundos}s',
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.gold,
            child: Text(
              '$numero',
              style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercicio?.nomeExibicao ?? 'Exercício não encontrado',
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                ),
                if (resumo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(resumo, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
                ],
                if (treinoExercicio.observacoes != null &&
                    treinoExercicio.observacoes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    treinoExercicio.observacoes!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
