import 'package:flutter/material.dart';

import '../../models/mensagem.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';

/// Central de mensagens do aluno — mostra o que a equipe (ADM/Personal
/// com a permissão `chat`) enviou pela tela "Enviar mensagem". Só
/// mensagens avulsas por enquanto; os avisos automáticos (vencimento de
/// mensalidade, reengajamento depois de 45 dias sem vir) ficam pra uma
/// etapa futura, com sua própria lógica de disparo.
class MensagensScreen extends StatelessWidget {
  const MensagensScreen({super.key, required this.uid, required this.alunoService});

  final String uid;
  final AlunoService alunoService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensagens')),
      body: SafeArea(
        child: StreamBuilder<List<Mensagem>>(
          stream: alunoService.watchMensagens(uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Erro ao carregar as mensagens.\n\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              );
            }

            final mensagens = snapshot.data ?? const <Mensagem>[];
            if (mensagens.isEmpty) {
              return Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: AppColors.textSecondary,
                        size: 56,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Nenhuma mensagem no momento',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Avisos de vencimento, comunicados da academia e outras '
                        'mensagens vão aparecer aqui.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: mensagens.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _CartaoMensagem(mensagem: mensagens[index]),
            );
          },
        ),
      ),
    );
  }
}

class _CartaoMensagem extends StatelessWidget {
  const _CartaoMensagem({required this.mensagem});

  final Mensagem mensagem;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fitness_center_outlined, color: AppColors.gold, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mensagem.remetenteNome,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                ),
              ),
              if (mensagem.criadoEm != null)
                Text(
                  _formatarDataHora(mensagem.criadoEm!),
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mensagem.texto,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  String _formatarDataHora(DateTime data) {
    final dia = data.day.toString().padLeft(2, '0');
    final mes = data.month.toString().padLeft(2, '0');
    final hora = data.hour.toString().padLeft(2, '0');
    final minuto = data.minute.toString().padLeft(2, '0');
    return '$dia/$mes · $hora:$minuto';
  }
}
