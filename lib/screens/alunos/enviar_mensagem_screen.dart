import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/escolher_aluno.dart';
import 'mensagens_enviadas_lista.dart';

/// Envia uma mensagem avulsa pra um aluno específico — só pra quem tem a
/// permissão `Permission.chat` (concedida pelo ADM, ver
/// `FuncionarioFormScreen`). O aluno vê o que for enviado aqui na tela
/// "Mensagens" da Área do Aluno (`MensagensScreen`).
///
/// Só o envio manual existe por enquanto — os avisos automáticos
/// (vencimento de mensalidade, reengajamento depois de 45 dias sem vir)
/// ficam pra uma etapa futura, com sua própria lógica de disparo.
class EnviarMensagemScreen extends StatefulWidget {
  const EnviarMensagemScreen({
    super.key,
    required this.alunoService,
    required this.staffAtual,
    this.alunoPreSelecionado,
  });

  final AlunoService alunoService;
  final AppUser staffAtual;

  /// Quando aberta a partir da ação rápida de um card na lista de alunos
  /// (ver `AlunosPorFiltroScreen`), já chega com o aluno certo escolhido —
  /// nesse caso o dropdown só confirma, não exige procurar de novo.
  final AppUser? alunoPreSelecionado;

  @override
  State<EnviarMensagemScreen> createState() => _EnviarMensagemScreenState();
}

class _EnviarMensagemScreenState extends State<EnviarMensagemScreen> {
  final _textoController = TextEditingController();
  late AppUser? _alunoSelecionado = widget.alunoPreSelecionado;
  bool _isSaving = false;

  @override
  void dispose() {
    _textoController.dispose();
    super.dispose();
  }

  Future<void> _handleEnviar() async {
    final aluno = _alunoSelecionado;
    final texto = _textoController.text.trim();
    if (aluno == null) {
      _mostrarErro('Selecione o aluno.');
      return;
    }
    if (texto.isEmpty) {
      _mostrarErro('Escreva a mensagem.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.alunoService.enviarMensagem(
        aluno.uid,
        texto: texto,
        remetenteUid: widget.staffAtual.uid,
        remetenteNome: widget.staffAtual.nome,
        alunoNome: aluno.nome,
      );
      if (mounted) {
        _textoController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Mensagem enviada para ${aluno.nome}.')),
        );
      }
    } catch (_) {
      _mostrarErro('Erro ao enviar a mensagem. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mensagens'),
          bottom: TabBar(
            labelColor: AppColors.gold,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.gold,
            tabs: const [
              Tab(text: 'ENVIAR'),
              Tab(text: 'ENVIADAS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildFormulario(),
            MensagensEnviadasLista(alunoService: widget.alunoService),
          ],
        ),
      ),
    );
  }

  Widget _buildFormulario() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<List<AppUser>>(
              stream: widget.alunoService.watchAlunos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(color: AppColors.gold),
                  );
                }

                return CampoAluno(
                  alunos: snapshot.data ?? const <AppUser>[],
                  uidSelecionado: _alunoSelecionado?.uid,
                  onChanged: (aluno) =>
                      setState(() => _alunoSelecionado = aluno),
                );
              },
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _textoController,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mensagem',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _handleEnviar,
              icon: _isSaving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.black,
                      ),
                    )
                  : const Icon(Icons.send_outlined),
              label: const Text('ENVIAR'),
            ),
          ],
        ),
      ),
    );
  }
}
