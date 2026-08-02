import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/aluno_service.dart';
import '../../theme/app_colors.dart';
import 'aluno_detail_screen.dart';
import 'aluno_form_screen.dart';

/// Lista de alunos cadastrados, ponto de entrada do ADM/Personal para a
/// ficha completa (dados, anamnese, termo e avaliacoes fisicas).
class AlunosListScreen extends StatefulWidget {
  const AlunosListScreen({super.key, required this.alunoService});

  final AlunoService alunoService;

  @override
  State<AlunosListScreen> createState() => _AlunosListScreenState();
}

class _AlunosListScreenState extends State<AlunosListScreen> {
  final _searchController = TextEditingController();
  String _busca = '';

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
            builder: (_) => AlunoFormScreen(alunoService: widget.alunoService),
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
              onChanged: (value) => setState(() => _busca = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Buscar aluno pelo nome',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: widget.alunoService.watchAlunos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Erro ao carregar os alunos.',
                      style: TextStyle(color: AppColors.error),
                    ),
                  );
                }

                final alunos = (snapshot.data ?? [])
                    .where((a) => _busca.isEmpty || a.nome.toLowerCase().contains(_busca))
                    .toList();

                if (alunos.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _busca.isEmpty
                            ? 'Nenhum aluno cadastrado ainda. Toque em "+" para '
                                  'cadastrar o primeiro.'
                            : 'Nenhum aluno encontrado para "$_busca".',
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
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.surfaceHigh,
                        child: Icon(Icons.fitness_center_outlined, color: AppColors.gold),
                      ),
                      title: Text(aluno.nome),
                      subtitle: Text(aluno.email, style: const TextStyle(color: AppColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlunoDetailScreen(
                            aluno: aluno,
                            alunoService: widget.alunoService,
                          ),
                        ),
                      ),
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
}
