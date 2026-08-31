import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

import '../../constants/dificuldade_exercicio.dart';
import '../../constants/equipamentos.dart';
import '../../constants/grupos_musculares.dart';
import '../../constants/musculos.dart';
import '../../models/exercise_model.dart';
import '../../theme/app_colors.dart';

/// Ficha de referência de um exercício da Biblioteca Oficial — usada ao
/// navegar a biblioteca (fora do fluxo de execução do treino, que tem
/// sua própria tela dedicada com player/controles).
///
/// Mostra o GIF animado de verdade (`gif360Url`, com fallback pro
/// `gif180Url`), não só o primeiro quadro — mesmo padrão de
/// `ExercicioMediaStage`/`ExercicioFullscreenScreen`.
class ExercicioDetailScreen extends StatefulWidget {
  const ExercicioDetailScreen({super.key, required this.exercicio});

  final ExerciseModel exercicio;

  @override
  State<ExercicioDetailScreen> createState() => _ExercicioDetailScreenState();
}

class _ExercicioDetailScreenState extends State<ExercicioDetailScreen>
    with SingleTickerProviderStateMixin {
  late final GifController _loopController;

  @override
  void initState() {
    super.initState();
    _loopController = GifController(vsync: this);
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercicio = widget.exercicio;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      appBar: AppBar(title: Text(exercicio.nomeExibicao, overflow: TextOverflow.ellipsis)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                color: AppColors.stage,
                child: Gif(
                  image: AssetImage(exercicio.gif360Url ?? exercicio.gif180Url),
                  controller: _loopController,
                  autostart: reduceMotion ? Autostart.no : Autostart.loop,
                  fit: BoxFit.cover,
                  placeholder: (_) => const Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (exercicio.bodyPart.isNotEmpty) _InfoChip(label: labelGrupoMuscular(exercicio.bodyPart)),
              if (exercicio.musculosPrincipais.isNotEmpty)
                _InfoChip(label: exercicio.musculosPrincipais.map(labelMusculo).join(', ')),
              if (exercicio.equipamentoTexto.isNotEmpty)
                _InfoChip(label: labelEquipamento(exercicio.equipamentoTexto)),
              if (exercicio.dificuldade.isNotEmpty)
                _InfoChip(label: labelDificuldade(exercicio.dificuldade)),
            ],
          ),
          if (exercicio.passoAPassoExibicao.isNotEmpty) ...[
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
            ...List.generate(exercicio.passoAPassoExibicao.length, (index) {
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
                        exercicio.passoAPassoExibicao[index],
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
