import 'package:flutter/material.dart';

import '../../models/avaliacao_fisica.dart';
import '../../constants/circunferencia_fields.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/imc.dart';

/// Histórico de avaliações físicas do próprio aluno — somente leitura
/// (quem cadastra é o personal/academia, ver `AvaliacoesTab`). Mais
/// recente primeiro, mesmos campos que já existem em
/// `AvaliacaoFisica` — não inventa métricas (ex.: %gordura, massa
/// muscular) que a ficha atual não tem.
class MinhasMedidasScreen extends StatelessWidget {
  const MinhasMedidasScreen({super.key, required this.uid, required this.alunoService});

  final String uid;
  final AlunoService alunoService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Minhas medidas')),
      body: SafeArea(
        child: StreamBuilder<List<AvaliacaoFisica>>(
          stream: alunoService.watchAvaliacoes(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Erro ao carregar suas avaliações.',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              );
            }

            final avaliacoes = snapshot.data ?? [];
            if (avaliacoes.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Você ainda não possui uma avaliação física cadastrada.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: avaliacoes.length,
              itemBuilder: (context, index) => _AvaliacaoCard(avaliacao: avaliacoes[index]),
            );
          },
        ),
      ),
    );
  }
}

class _AvaliacaoCard extends StatefulWidget {
  const _AvaliacaoCard({required this.avaliacao});

  final AvaliacaoFisica avaliacao;

  @override
  State<_AvaliacaoCard> createState() => _AvaliacaoCardState();
}

class _AvaliacaoCardState extends State<_AvaliacaoCard> {
  bool _expandido = false;

  @override
  Widget build(BuildContext context) {
    final avaliacao = widget.avaliacao;
    final imc = avaliacao.imc;
    final circunferencias = circunferenciaFields
        .where((campo) => avaliacao.circunferenciasCm[campo.key] != null)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatarData(avaliacao.data),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              if (imc != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: classificarImc(imc).cor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'IMC ${imc.toStringAsFixed(1)} · ${classificarImc(imc).rotulo}',
                    style: TextStyle(
                      color: classificarImc(imc).cor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 6,
            children: [
              if (avaliacao.pesoKg != null) _InfoChip('Peso', '${avaliacao.pesoKg} kg'),
              if (avaliacao.alturaM != null) _InfoChip('Altura', '${avaliacao.alturaM} m'),
            ],
          ),
          if (circunferencias.isNotEmpty) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: () => setState(() => _expandido = !_expandido),
              child: Row(
                children: [
                  Text(
                    _expandido ? 'Ocultar circunferências' : 'Ver ${circunferencias.length} circunferências',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    _expandido ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textSecondary,
                    size: 18,
                  ),
                ],
              ),
            ),
            if (_expandido) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 20,
                runSpacing: 6,
                children: [
                  for (final campo in circunferencias)
                    _InfoChip(
                      campo.label,
                      '${avaliacao.circunferenciasCm[campo.key]!.toStringAsFixed(1)} cm',
                    ),
                ],
              ),
            ],
          ],
          if (avaliacao.observacoes != null && avaliacao.observacoes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              avaliacao.observacoes!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  String _formatarData(DateTime data) {
    return '${data.day.toString().padLeft(2, '0')}/'
        '${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip(this.label, this.valor);

  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        children: [
          TextSpan(text: '$label: '),
          TextSpan(
            text: valor,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
