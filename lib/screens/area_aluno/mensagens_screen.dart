import 'package:flutter/material.dart';

import '../../models/mensagem.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';

/// Central de avisos do aluno — mostra o que a equipe (ADM/Personal com a
/// permissão `chat`) enviou pela tela "Mensagens". A comunicação é de mão
/// única por decisão de produto: o aluno lê e pode tirar da lista, mas
/// não responde.
///
/// Só avisos avulsos por enquanto; os automáticos (vencimento de
/// mensalidade, reengajamento depois de 45 dias sem vir) ficam pra uma
/// etapa futura, com sua própria lógica de disparo.
class MensagensScreen extends StatefulWidget {
  const MensagensScreen({
    super.key,
    required this.uid,
    required this.alunoService,
  });

  final String uid;
  final AlunoService alunoService;

  @override
  State<MensagensScreen> createState() => _MensagensScreenState();
}

class _MensagensScreenState extends State<MensagensScreen> {
  /// Ids já mandados pro servidor nesta visita. Sem isso, cada reemissão
  /// do stream (inclusive a causada pela própria marcação) dispararia a
  /// escrita de novo, em laço.
  final _jaMarcadas = <String>{};

  /// Abrir a tela é o ato de ler: os avisos aparecem inteiros na lista,
  /// não há "abrir a mensagem" pra usar como gatilho mais preciso.
  void _marcarComoLidas(List<Mensagem> mensagens) {
    final novas = mensagens
        .where((m) => !m.lida && m.id != null && !_jaMarcadas.contains(m.id))
        .map((m) => m.id!)
        .toList();
    if (novas.isEmpty) return;

    _jaMarcadas.addAll(novas);
    // Fora do ciclo de build: isto roda de dentro do builder do
    // StreamBuilder, e escrever ali dispararia setState durante o build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.alunoService.marcarMensagensComoLidas(widget.uid, novas);
    });
  }

  Future<void> _apagar(Mensagem mensagem) async {
    try {
      await widget.alunoService.arquivarMensagem(widget.uid, mensagem.id!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao apagar o aviso.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mensagens')),
      body: SafeArea(
        child: StreamBuilder<List<Mensagem>>(
          stream: widget.alunoService.watchMensagens(widget.uid),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
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
            _marcarComoLidas(mensagens);

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
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
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
              itemBuilder: (context, index) {
                final mensagem = mensagens[index];
                return _CartaoMensagem(
                  mensagem: mensagem,
                  aoApagar: mensagem.id == null
                      ? null
                      : () => _apagar(mensagem),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CartaoMensagem extends StatelessWidget {
  const _CartaoMensagem({required this.mensagem, this.aoApagar});

  final Mensagem mensagem;
  final VoidCallback? aoApagar;

  @override
  Widget build(BuildContext context) {
    // Não lida ganha borda dourada: dentro da própria lista é o que
    // separa o que chegou agora do que o aluno já viu.
    final naoLida = !mensagem.lida;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: naoLida ? AppColors.gold : AppColors.surfaceHigh,
          width: naoLida ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.fitness_center_outlined,
                color: AppColors.gold,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mensagem.remetenteNome,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (mensagem.criadoEm != null)
                Text(
                  _formatarDataHora(mensagem.criadoEm!),
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              if (aoApagar != null)
                IconButton(
                  onPressed: aoApagar,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 19,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: 'Apagar',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 6),
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mensagem.texto,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.4,
            ),
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
