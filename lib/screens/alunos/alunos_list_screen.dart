import 'package:flutter/material.dart';

import '../../models/aluno.dart';
import '../../models/app_user.dart';
import '../../services/aluno_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/status_operacional_aluno.dart';
import 'aluno_detail_screen.dart';
import 'novo_aluno_wizard_screen.dart';

/// Lista de alunos cadastrados, ponto de entrada do ADM/Personal para a
/// ficha completa (dados, anamnese, termo, avaliacoes fisicas e treino).
class AlunosListScreen extends StatefulWidget {
  const AlunosListScreen({
    super.key,
    required this.alunoService,
    required this.storageService,
    required this.staffAtual,
  });

  final AlunoService alunoService;
  final StorageService storageService;
  final AppUser staffAtual;

  @override
  State<AlunosListScreen> createState() => _AlunosListScreenState();
}

class _AlunosListScreenState extends State<AlunosListScreen> {
  final _searchController = TextEditingController();
  String _busca = '';
  FiltroStatusAluno _filtro = FiltroStatusAluno.todos;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alunos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NovoAlunoWizardScreen(
              alunoService: widget.alunoService,
              storageService: widget.storageService,
              staffAtual: widget.staffAtual,
            ),
          ),
        ),
        tooltip: 'Novo aluno',
        child: const Icon(Icons.person_add_outlined),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) =>
                  setState(() => _busca = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Buscar aluno pelo nome',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: FiltroStatusAluno.values.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final filtro = FiltroStatusAluno.values[index];
                  return ChoiceChip(
                    label: Text(filtro.label),
                    selected: _filtro == filtro,
                    onSelected: (_) => setState(() => _filtro = filtro),
                    selectedColor: AppColors.gold,
                    backgroundColor: AppColors.surface,
                    labelStyle: TextStyle(
                      color: _filtro == filtro ? AppColors.black : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Aluno>>(
              stream: widget.alunoService.watchTodosAlunos(),
              builder: (context, fichasSnapshot) {
                final fichasPorUid = {
                  for (final ficha in fichasSnapshot.data ?? const <Aluno>[]) ficha.uid: ficha,
                };

                return StreamBuilder<List<AppUser>>(
                  stream: widget.alunoService.watchAlunos(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      // Mostra o erro real (não só uma mensagem genérica): a
                      // causa mais provável é o Firestore exigir um índice
                      // composto pra essa consulta (where + orderBy em campos
                      // diferentes) — o erro do Firestore normalmente já vem
                      // com um link direto pra criar o índice que falta.
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              'Erro ao carregar os alunos.\n\n${snapshot.error}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ),
                      );
                    }

                    final alunos = (snapshot.data ?? [])
                        .where(
                          (a) =>
                              _busca.isEmpty ||
                              a.nome.toLowerCase().contains(_busca),
                        )
                        .where((a) => alunoPassaNoFiltro(fichasPorUid[a.uid], _filtro))
                        .toList();

                    if (alunos.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _busca.isNotEmpty
                                ? 'Nenhum aluno encontrado para "$_busca".'
                                : _filtro == FiltroStatusAluno.todos
                                ? 'Nenhum aluno cadastrado ainda. Toque em "+" para '
                                      'cadastrar o primeiro.'
                                : 'Nenhum aluno em "${_filtro.label}".',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 88),
                      itemCount: alunos.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1, color: AppColors.surfaceHigh),
                      itemBuilder: (context, index) {
                        final aluno = alunos[index];
                        final ficha = fichasPorUid[aluno.uid];
                        final status = ficha != null ? calcularStatusOperacional(ficha) : null;
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppColors.surfaceHigh,
                            child: Icon(
                              Icons.fitness_center_outlined,
                              color: AppColors.gold,
                            ),
                          ),
                          title: Text(aluno.nome),
                          subtitle: Text(
                            status != null ? '${aluno.email} · ${status.label}' : aluno.email,
                            style: TextStyle(
                              color: status == null
                                  ? AppColors.textSecondary
                                  : _corStatusOperacional(status),
                            ),
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlunoDetailScreen(
                                aluno: aluno,
                                alunoService: widget.alunoService,
                                storageService: widget.storageService,
                                staffAtual: widget.staffAtual,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _corStatusOperacional(StatusOperacionalAluno status) {
    switch (status) {
      case StatusOperacionalAluno.ativo:
        return const Color(0xFF4CAF6D);
      case StatusOperacionalAluno.inadimplente:
        return AppColors.error;
      case StatusOperacionalAluno.inativo:
        return AppColors.textSecondary;
    }
  }
}
