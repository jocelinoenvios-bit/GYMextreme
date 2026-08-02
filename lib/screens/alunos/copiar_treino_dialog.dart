import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/treino.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';

/// Dialogo em 2 passos: escolhe o aluno de origem, depois escolhe qual
/// treino dele copiar pro aluno atual (`alunoDestinoUid`).
class CopiarTreinoDialog extends StatefulWidget {
  const CopiarTreinoDialog({
    super.key,
    required this.alunoDestinoUid,
    required this.alunoService,
    required this.staffAtual,
  });

  final String alunoDestinoUid;
  final AlunoService alunoService;
  final AppUser staffAtual;

  @override
  State<CopiarTreinoDialog> createState() => _CopiarTreinoDialogState();
}

class _CopiarTreinoDialogState extends State<CopiarTreinoDialog> {
  AppUser? _origemSelecionada;
  bool _copiando = false;

  Future<void> _copiar(Treino treino) async {
    setState(() => _copiando = true);
    try {
      await widget.alunoService.copiarTreinoDeOutroAluno(
        origemUid: _origemSelecionada!.uid,
        treinoId: treino.id!,
        destinoUid: widget.alunoDestinoUid,
        staffUid: widget.staffAtual.uid,
        staffNome: widget.staffAtual.nome,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Treino "${treino.nome}" copiado.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _copiando = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro ao copiar o treino. Tente novamente.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(_origemSelecionada == null ? 'Copiar de qual aluno?' : 'Copiar qual treino?'),
      content: SizedBox(
        width: double.maxFinite,
        height: 360,
        child: _origemSelecionada == null ? _listaDeAlunos() : _listaDeTreinos(),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (_origemSelecionada != null) {
              setState(() => _origemSelecionada = null);
            } else {
              Navigator.of(context).pop();
            }
          },
          child: Text(_origemSelecionada == null ? 'Cancelar' : 'Voltar'),
        ),
      ],
    );
  }

  Widget _listaDeAlunos() {
    return StreamBuilder<List<AppUser>>(
      stream: widget.alunoService.watchAlunos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final alunos = (snapshot.data ?? [])
            .where((a) => a.uid != widget.alunoDestinoUid)
            .toList();
        if (alunos.isEmpty) {
          return const Center(
            child: Text(
              'Nenhum outro aluno cadastrado.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: alunos.length,
          itemBuilder: (context, index) {
            final aluno = alunos[index];
            return ListTile(
              title: Text(aluno.nome),
              onTap: () => setState(() => _origemSelecionada = aluno),
            );
          },
        );
      },
    );
  }

  Widget _listaDeTreinos() {
    if (_copiando) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<List<Treino>>(
      stream: widget.alunoService.watchTreinos(_origemSelecionada!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final treinos = snapshot.data ?? [];
        if (treinos.isEmpty) {
          return Text(
            '${_origemSelecionada!.nome} ainda não tem nenhum treino cadastrado.',
            style: const TextStyle(color: AppColors.textSecondary),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: treinos.length,
          itemBuilder: (context, index) {
            final treino = treinos[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.gold,
                child: Text(
                  treino.letra,
                  style: const TextStyle(color: AppColors.black, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(treino.nome),
              subtitle: Text('${treino.exercicios.length} exercício(s)'),
              onTap: () => _copiar(treino),
            );
          },
        );
      },
    );
  }
}
