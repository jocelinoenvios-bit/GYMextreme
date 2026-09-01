import 'package:flutter/material.dart';

import '../../constants/dificuldade_exercicio.dart';
import '../../constants/equipamentos.dart';
import '../../constants/grupos_musculares.dart';
import '../../constants/musculos.dart';
import '../../models/exercise_model.dart';
import '../../services/gif_cache_service.dart';
import '../../theme/app_colors.dart';
import '../area_aluno/widgets/exercicio_midia.dart';

/// Ficha de referência de um exercício da Biblioteca Oficial — usada ao
/// navegar a biblioteca (fora do fluxo de execução do treino, que tem
/// sua própria tela dedicada com player/controles).
///
/// Mostra a mídia animada de verdade — vídeo da Vital Animations
/// (`videoUrl`) quando existir, GIF (`gif360Url`) caso contrário —,
/// não só o primeiro quadro — mesmo
/// padrão de `ExercicioMediaStage`/`ExercicioFullscreenScreen`, mas sem
/// os controles manuais (aqui é só referência, sempre em loop).
class ExercicioDetailScreen extends StatefulWidget {
  const ExercicioDetailScreen({super.key, required this.exercicio, this.gifCacheService});

  final ExerciseModel exercicio;

  /// Injetável pra teste (`FakeGifCacheService`) — em produção usa o
  /// padrão de `ExercicioMidia` (`FirebaseGifCacheService()`).
  final GifCacheService? gifCacheService;

  @override
  State<ExercicioDetailScreen> createState() => _ExercicioDetailScreenState();
}

class _ExercicioDetailScreenState extends State<ExercicioDetailScreen> {
  late final ExercicioMidiaController _midiaController;

  @override
  void initState() {
    super.initState();
    _midiaController = ExercicioMidiaController(tocandoInicial: true);
  }

  @override
  void dispose() {
    _midiaController.dispose();
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
                child: ExercicioMidia(
                  exercise: exercicio,
                  controller: _midiaController,
                  fit: BoxFit.cover,
                  reduceMotion: reduceMotion,
                  gifCacheService: widget.gifCacheService,
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
