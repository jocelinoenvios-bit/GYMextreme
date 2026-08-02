import 'package:flutter/material.dart';

import '../../../models/avaliacao_fisica.dart';
import '../../../services/aluno_service.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/imc.dart';
import '../avaliacao_fisica_form_screen.dart';

/// Historico de avaliacoes fisicas do aluno, mais recente primeiro —
/// equivalente as 3 colunas "AVALIACAO FISICA __/__/__" da ficha em
/// papel, so que sem limite de quantas.
class AvaliacoesTab extends StatelessWidget {
  const AvaliacoesTab({super.key, required this.uid, required this.alunoService});

  final String uid;
  final AlunoService alunoService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AvaliacaoFisicaFormScreen(uid: uid, alunoService: alunoService),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Nova avaliação'),
      ),
      body: StreamBuilder<List<AvaliacaoFisica>>(
        stream: alunoService.watchAvaliacoes(uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Erro ao carregar as avaliações.',
                style: TextStyle(color: AppColors.error),
              ),
            );
          }

          final avaliacoes = snapshot.data ?? [];
          if (avaliacoes.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma avaliação física registrada ainda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: avaliacoes.length,
            itemBuilder: (context, index) => _AvaliacaoCard(avaliacao: avaliacoes[index]),
          );
        },
      ),
    );
  }
}

class _AvaliacaoCard extends StatelessWidget {
  const _AvaliacaoCard({required this.avaliacao});

  final AvaliacaoFisica avaliacao;

  @override
  Widget build(BuildContext context) {
    final imc = avaliacao.imc;
    final circunferenciasPreenchidas = avaliacao.circunferenciasCm.entries
        .where((e) => e.value != null)
        .length;

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
                    'IMC ${imc.toStringAsFixed(1)}',
                    style: TextStyle(
                      color: classificarImc(imc).cor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              if (avaliacao.pesoKg != null)
                _InfoChip('Peso', '${avaliacao.pesoKg} kg'),
              if (avaliacao.alturaM != null)
                _InfoChip('Altura', '${avaliacao.alturaM} m'),
              if (circunferenciasPreenchidas > 0)
                _InfoChip('Circunferências', '$circunferenciasPreenchidas medidas'),
            ],
          ),
          if (avaliacao.observacoes != null && avaliacao.observacoes!.isNotEmpty) ...[
            const SizedBox(height: 8),
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
