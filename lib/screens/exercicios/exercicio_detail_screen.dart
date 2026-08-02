import 'package:flutter/material.dart';

import '../../constants/grupos_musculares.dart';
import '../../models/exercicio.dart';
import '../../theme/app_colors.dart';

class ExercicioDetailScreen extends StatelessWidget {
  const ExercicioDetailScreen({super.key, required this.exercicio});

  final Exercicio exercicio;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(exercicio.nome, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (exercicio.gifUrl != null && exercicio.gifUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1,
                child: Image.network(
                  exercicio.gifUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const _GifIndisponivel(),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (exercicio.grupoMuscular.isNotEmpty)
                _InfoChip(label: labelGrupoMuscular(exercicio.grupoMuscular)),
              if (exercicio.alvo.isNotEmpty) _InfoChip(label: exercicio.alvo),
              if (exercicio.equipamento.isNotEmpty) _InfoChip(label: exercicio.equipamento),
              if (exercicio.nivel != null && exercicio.nivel!.isNotEmpty)
                _InfoChip(label: exercicio.nivel!),
            ],
          ),
          if (exercicio.instrucoes.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Instruções',
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(exercicio.instrucoes.length, (index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${index + 1}. ',
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(
                        exercicio.instrucoes[index],
                        style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _GifIndisponivel extends StatelessWidget {
  const _GifIndisponivel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined, color: AppColors.textSecondary, size: 40),
    );
  }
}
