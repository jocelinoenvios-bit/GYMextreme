import 'package:flutter/material.dart';

import '../../../constants/grupos_musculares.dart';
import '../../../constants/musculos.dart';
import '../../../models/exercise_model.dart';
import '../../../theme/app_colors.dart';

/// Toda a informação didática do exercício, abaixo do palco — nesta
/// ordem exata: nome/grupo muscular, passo a passo, respiração,
/// amplitude, músculos trabalhados, erros comuns, cuidados, ajuste da
/// máquina, observação do personal. Cada seção só aparece se houver
/// dado (nem todo exercício tem ajuste de máquina, por exemplo).
class ExercicioInfoList extends StatelessWidget {
  const ExercicioInfoList({super.key, required this.prescricao});

  final ExercisePrescription prescricao;

  @override
  Widget build(BuildContext context) {
    final exercicio = prescricao.exercise;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                exercicio.nomeExibicao,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _Chip(texto: labelGrupoMuscular(exercicio.grupoMuscular), cor: AppColors.gold),
          ],
        ),
        const SizedBox(height: 16),
        if (exercicio.passoAPassoExibicao.isNotEmpty)
          _InfoCard(
            icone: Icons.checklist_rounded,
            label: 'Passo a passo',
            child: _ListaNumerada(itens: exercicio.passoAPassoExibicao),
          ),
        if (exercicio.respiracao != null)
          _InfoCard(
            icone: Icons.air_rounded,
            label: 'Respiração',
            child: _Paragrafo(exercicio.respiracao!),
          ),
        if (exercicio.amplitude != null)
          _InfoCard(
            icone: Icons.swap_vert_rounded,
            label: 'Amplitude correta',
            child: _Paragrafo(exercicio.amplitude!),
          ),
        if (exercicio.musculosPrincipais.isNotEmpty || exercicio.musculosAuxiliares.isNotEmpty)
          _InfoCard(
            icone: Icons.accessibility_new_rounded,
            label: 'Músculos trabalhados',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final musculo in exercicio.musculosPrincipais)
                  _MusculoTag(nome: labelMusculo(musculo), cor: AppColors.musclePrimary),
                for (final musculo in exercicio.musculosAuxiliares)
                  _MusculoTag(nome: labelMusculo(musculo), cor: AppColors.muscleSecondary),
              ],
            ),
          ),
        if (exercicio.errosComuns.isNotEmpty)
          _InfoCard(
            icone: Icons.report_gmailerrorred_rounded,
            label: 'Erros mais comuns',
            child: _ListaComMarcador(itens: exercicio.errosComuns),
          ),
        if (exercicio.cuidados != null)
          _InfoCard(
            icone: Icons.shield_outlined,
            label: 'Cuidados para evitar lesões',
            child: _Paragrafo(exercicio.cuidados!),
          ),
        if (exercicio.ajusteMaquina != null)
          _InfoCard(
            icone: Icons.settings_outlined,
            label: 'Ajuste da máquina',
            child: _Paragrafo(exercicio.ajusteMaquina!),
          ),
        if (prescricao.observacoesPersonal != null)
          _InfoCard(
            icone: Icons.star_rounded,
            label: 'Observação do seu personal',
            destaque: true,
            child: _Paragrafo(
              prescricao.observacoesPersonal!,
              destaque: true,
            ),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icone,
    required this.label,
    required this.child,
    this.destaque = false,
  });

  final IconData icone;
  final String label;
  final Widget child;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: destaque ? AppColors.gold.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: destaque ? Border.all(color: AppColors.gold.withValues(alpha: 0.5)) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 15, color: destaque ? AppColors.goldBright : AppColors.gold),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: destaque ? AppColors.goldBright : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _ListaNumerada extends StatelessWidget {
  const _ListaNumerada({required this.itens});

  final List<String> itens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < itens.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1}.',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    itens[i],
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ListaComMarcador extends StatelessWidget {
  const _ListaComMarcador({required this.itens});

  final List<String> itens;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in itens)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6, right: 8),
                  child: Icon(Icons.circle, size: 4, color: AppColors.textSecondary),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Paragrafo extends StatelessWidget {
  const _Paragrafo(this.texto, {this.destaque = false});

  final String texto;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        color: AppColors.textPrimary,
        fontWeight: destaque ? FontWeight.w600 : FontWeight.normal,
        fontStyle: destaque ? FontStyle.italic : FontStyle.normal,
        fontSize: 13,
        height: 1.4,
      ),
    );
  }
}

class _MusculoTag extends StatelessWidget {
  const _MusculoTag({required this.nome, required this.cor});

  final String nome;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 7, color: cor),
          const SizedBox(width: 6),
          Text(nome, style: TextStyle(color: cor, fontSize: 11.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.texto, required this.cor});

  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texto,
        style: TextStyle(color: cor, fontSize: 11.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
