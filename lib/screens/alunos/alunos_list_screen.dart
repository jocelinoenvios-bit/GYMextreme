import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/permission.dart';
import '../../services/aluno_service.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/premium.dart';
import '../../utils/status_operacional_aluno.dart';
import 'aluno_detail_screen.dart';
import 'aviso_sem_vencimento.dart';
import 'alunos_por_filtro_screen.dart';

/// Hub de "Alunos": busca pelo nome + os 6 grupos (`FiltroStatusAluno`)
/// como cards quadrados — cada card abre `AlunosPorFiltroScreen` já
/// filtrada. Buscar por nome ignora o agrupamento (substitui os cards
/// pela lista de resultados, cruzando todos os alunos).
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alunos')),
      // Sem botão de "novo aluno" aqui de propósito: o cadastro fica na
      // tela Matrículas, ao lado de "Nova matrícula" (ver
      // MatriculasListScreen) — os dois começos de atendimento juntos.
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _busca = value.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Buscar aluno pelo nome',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: 20),
              // Alunos antigos, de antes do vencimento automático — só pra
              // quem pode mexer em mensalidade.
              if (_busca.isEmpty &&
                  PermissionService.has(widget.staffAtual, Permission.receberMensalidades))
                AvisoSemVencimento(alunoService: widget.alunoService),
              Expanded(
                child: _busca.isEmpty ? _buildGradeFiltros(context) : _buildResultadosBusca(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGradeFiltros(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      padding: const EdgeInsets.only(bottom: 16),
      children: FiltroStatusAluno.values.map((filtro) {
        return _CardFiltroAluno(
          filtro: filtro,
          destaque: filtro == FiltroStatusAluno.todos,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AlunosPorFiltroScreen(
                filtro: filtro,
                alunoService: widget.alunoService,
                storageService: widget.storageService,
                staffAtual: widget.staffAtual,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildResultadosBusca() {
    return StreamBuilder<List<AppUser>>(
      stream: widget.alunoService.watchAlunos(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: SelectableText(
                  'Erro ao carregar os alunos.\n\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ),
          );
        }

        final alunos = (snapshot.data ?? [])
            .where((a) => a.nome.toLowerCase().contains(_busca))
            .toList();

        if (alunos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Nenhum aluno encontrado para "$_busca".',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: alunos.length,
          separatorBuilder: (context, index) =>
              Divider(height: 1, color: AppColors.surfaceHigh),
          itemBuilder: (context, index) {
            final aluno = alunos[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.surfaceHigh,
                child: Icon(Icons.fitness_center_outlined, color: AppColors.gold),
              ),
              title: Text(aluno.nome),
              subtitle: Text(aluno.email, style: TextStyle(color: AppColors.textSecondary)),
              trailing: Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
  }
}

/// Um card quadrado de cantos arredondados pra um grupo de alunos —
/// "Todos" vem em destaque (fundo dourado), os demais em cinza escuro com
/// ícone dourado, mesmo padrão visual da tela inicial do aluno.
class _CardFiltroAluno extends StatelessWidget {
  const _CardFiltroAluno({required this.filtro, required this.destaque, required this.onTap});

  final FiltroStatusAluno filtro;
  final bool destaque;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final corIcone = destaque ? OuroPremium.tinta : AppColors.gold;
    final corTexto = destaque ? OuroPremium.tinta : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          gradient: destaque ? OuroPremium.degrade : DecoracaoPremium.gradienteCard,
          borderRadius: BorderRadius.circular(16),
          border: destaque ? null : Border.all(color: DecoracaoPremium.bordaCard),
          boxShadow: DecoracaoPremium.sombraCard,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconeFor(filtro), color: corIcone, size: 22),
            const SizedBox(height: 8),
            Text(
              filtro.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: corTexto,
                fontWeight: destaque ? FontWeight.bold : FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconeFor(FiltroStatusAluno filtro) {
    switch (filtro) {
      case FiltroStatusAluno.todos:
        return Icons.groups_outlined;
      case FiltroStatusAluno.ativos:
        return Icons.check_circle_outline;
      case FiltroStatusAluno.inadimplentes:
        return Icons.error_outline;
      case FiltroStatusAluno.inativos:
        return Icons.block_outlined;
      case FiltroStatusAluno.atraso15Dias:
        return Icons.schedule_outlined;
      case FiltroStatusAluno.inatividade45Dias:
        return Icons.history_outlined;
    }
  }
}
