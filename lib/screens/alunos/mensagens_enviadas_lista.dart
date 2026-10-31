import 'package:flutter/material.dart';

import '../../models/mensagem.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';

/// Tudo que a equipe já enviou, de todos os alunos — responde "o que eu
/// mandei, pra quem e quando", que antes se perdia assim que a mensagem
/// saía (ela só existia do lado de quem recebe).
///
/// Mostra também se o aluno já abriu, que é metade do valor de um aviso
/// de vencimento: saber se chegou a ser visto.
class MensagensEnviadasLista extends StatefulWidget {
  const MensagensEnviadasLista({super.key, required this.alunoService});

  final AlunoService alunoService;

  @override
  State<MensagensEnviadasLista> createState() => _MensagensEnviadasListaState();
}

class _MensagensEnviadasListaState extends State<MensagensEnviadasLista> {
  final _buscaController = TextEditingController();
  String _busca = '';

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Future<void> _confirmarApagar(Mensagem mensagem) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apagar mensagem?'),
        content: Text(
          'A mensagem enviada para ${mensagem.alunoNome} será apagada '
          'também da tela dele.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('APAGAR', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmou != true || !mounted) return;

    try {
      await widget.alunoService.apagarMensagem(
        mensagem.alunoUid,
        mensagem.id!,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao apagar a mensagem.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _buscaController,
              onChanged: (valor) =>
                  setState(() => _busca = valor.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Buscar pelo nome do aluno',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Mensagem>>(
              stream: widget.alunoService.watchMensagensEnviadas(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _Aviso(
                    icone: Icons.error_outline,
                    texto:
                        'Erro ao carregar as mensagens enviadas.\n\n'
                        '${snapshot.error}',
                    cor: AppColors.error,
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  );
                }

                final todas = snapshot.data ?? const <Mensagem>[];
                final mensagens = _busca.isEmpty
                    ? todas
                    : todas
                          .where(
                            (m) => m.alunoNome.toLowerCase().contains(_busca),
                          )
                          .toList();

                if (mensagens.isEmpty) {
                  return _Aviso(
                    icone: Icons.outgoing_mail,
                    texto: todas.isEmpty
                        ? 'Nenhuma mensagem enviada ainda.'
                        : 'Nenhuma mensagem para esse aluno.',
                    cor: AppColors.textSecondary,
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: mensagens.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) => _CartaoEnviada(
                    mensagem: mensagens[index],
                    aoApagar: () => _confirmarApagar(mensagens[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CartaoEnviada extends StatelessWidget {
  const _CartaoEnviada({required this.mensagem, required this.aoApagar});

  final Mensagem mensagem;
  final VoidCallback aoApagar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.surfaceHigh),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, size: 17, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  mensagem.alunoNome.isEmpty
                      ? 'Aluno removido'
                      : mensagem.alunoNome,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: mensagem.id == null ? null : aoApagar,
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                tooltip: 'Apagar',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(mensagem.texto, style: TextStyle(color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                mensagem.lida ? Icons.done_all : Icons.schedule,
                size: 14,
                color: mensagem.lida ? AppColors.gold : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                mensagem.lida ? 'Lida' : 'Não lida',
                style: TextStyle(
                  color: mensagem.lida
                      ? AppColors.gold
                      : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _formatar(mensagem.criadoEm),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Vazio enquanto o `serverTimestamp` não volta do servidor — mostrar
  /// o relógio do aparelho aqui seria inventar uma data.
  static String _formatar(DateTime? data) {
    if (data == null) return '';
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(data.day)}/${d(data.month)}/${data.year} ${d(data.hour)}:${d(data.minute)}';
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icone, required this.texto, required this.cor});

  final IconData icone;
  final String texto;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 44, color: cor),
            const SizedBox(height: 14),
            Text(texto, textAlign: TextAlign.center, style: TextStyle(color: cor)),
          ],
        ),
      ),
    );
  }
}
