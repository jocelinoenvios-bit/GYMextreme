import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../theme/app_colors.dart';
import '../utils/busca.dart';

/// Abre a janela de escolher aluno, com barra de pesquisa. Devolve o aluno
/// escolhido, ou `null` se a pessoa fechou sem escolher.
///
/// É o único jeito de escolher aluno no app — com muita gente cadastrada,
/// uma lista corrida (dropdown) fica impossível de usar.
Future<AppUser?> escolherAluno(
  BuildContext context, {
  required List<AppUser> alunos,
  String titulo = 'Escolha o aluno',
}) {
  return showDialog<AppUser>(
    context: context,
    builder: (_) => _JanelaEscolherAluno(alunos: alunos, titulo: titulo),
  );
}

class _JanelaEscolherAluno extends StatefulWidget {
  const _JanelaEscolherAluno({required this.alunos, required this.titulo});

  final List<AppUser> alunos;
  final String titulo;

  @override
  State<_JanelaEscolherAluno> createState() => _JanelaEscolherAlunoState();
}

class _JanelaEscolherAlunoState extends State<_JanelaEscolherAluno> {
  String _busca = '';

  /// Sem repetidos (o mesmo uid pode chegar duas vezes do Firestore) e em
  /// ordem alfabética, ignorando acento e maiúscula.
  late final List<AppUser> _alunos = () {
    final porUid = <String, AppUser>{for (final a in widget.alunos) a.uid: a};
    return porUid.values.toList()
      ..sort((a, b) => paraBusca(a.nome).compareTo(paraBusca(b.nome)));
  }();

  @override
  Widget build(BuildContext context) {
    final termo = paraBusca(_busca.trim());
    final encontrados = termo.isEmpty
        ? _alunos
        : _alunos
              .where(
                (a) =>
                    paraBusca(a.nome).contains(termo) ||
                    paraBusca(a.email).contains(termo),
              )
              .toList();

    return AlertDialog(
      title: Text(widget.titulo),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      content: SizedBox(
        width: double.maxFinite,
        // Altura fixa: com a lista encolhendo enquanto se digita, a janela
        // pularia de tamanho a cada letra.
        height: 420,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              onChanged: (valor) => setState(() => _busca = valor),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'Pesquisar pelo nome',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: encontrados.isEmpty
                  ? Center(
                      child: Text(
                        _alunos.isEmpty
                            ? 'Nenhum aluno cadastrado.'
                            : 'Nenhum aluno encontrado com "${_busca.trim()}".',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      itemCount: encontrados.length,
                      itemBuilder: (context, index) {
                        final aluno = encontrados[index];
                        return ListTile(
                          title: Text(aluno.nome),
                          subtitle: aluno.email.isEmpty
                              ? null
                              : Text(
                                  aluno.email,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12.5,
                                  ),
                                ),
                          onTap: () => Navigator.of(context).pop(aluno),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCELAR'),
        ),
      ],
    );
  }
}

/// Campo de formulário "Aluno": mostra quem está escolhido e, ao tocar,
/// abre [escolherAluno]. Toma o lugar dos dropdowns de aluno.
///
/// Com [textoNenhum] (ex.: "Todos", nos filtros), aparece também um X pra
/// voltar a "nenhum aluno" depois de escolher um.
class CampoAluno extends StatelessWidget {
  const CampoAluno({
    super.key,
    required this.alunos,
    required this.uidSelecionado,
    required this.onChanged,
    this.rotulo = 'Aluno',
    this.textoNenhum,
    this.isDense = false,
  });

  final List<AppUser> alunos;

  /// Pelo uid, e não pelo AppUser: se o aluno sumir da lista (excluído
  /// com a tela aberta), o campo simplesmente volta a ficar vazio.
  final String? uidSelecionado;
  final ValueChanged<AppUser?> onChanged;
  final String rotulo;
  final String? textoNenhum;
  final bool isDense;

  AppUser? get _selecionado {
    for (final aluno in alunos) {
      if (aluno.uid == uidSelecionado) return aluno;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selecionado = _selecionado;
    final semAlunos = alunos.isEmpty;
    final podeLimpar = textoNenhum != null && selecionado != null;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: semAlunos
          ? null
          : () async {
              final escolhido = await escolherAluno(context, alunos: alunos);
              if (escolhido != null) onChanged(escolhido);
            },
      child: InputDecorator(
        isEmpty: selecionado == null && textoNenhum == null,
        decoration: InputDecoration(
          labelText: rotulo,
          isDense: isDense,
          enabled: !semAlunos,
          helperText: semAlunos ? 'Nenhum aluno cadastrado' : null,
          suffixIcon: podeLimpar
              ? IconButton(
                  tooltip: 'Limpar',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.search),
        ),
        child: Text(
          selecionado?.nome ?? textoNenhum ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
