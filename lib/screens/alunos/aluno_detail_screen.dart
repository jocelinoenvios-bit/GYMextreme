import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/permission.dart';
import '../../services/aluno_service.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import 'tabs/anamnese_tab.dart';
import 'tabs/avaliacoes_tab.dart';
import 'tabs/dados_tab.dart';
import 'tabs/termo_tab.dart';
import 'tabs/treinos_tab.dart';

/// Ficha completa do aluno, em abas: dados de cadastro, anamnese, termo
/// de responsabilidade, historico de avaliacoes fisicas e (se o usuario
/// logado tiver a permissao) fichas de treino.
class AlunoDetailScreen extends StatelessWidget {
  const AlunoDetailScreen({
    super.key,
    required this.aluno,
    required this.alunoService,
    required this.storageService,
    required this.staffAtual,
  });

  final AppUser aluno;
  final AlunoService alunoService;
  final StorageService storageService;
  final AppUser staffAtual;

  @override
  Widget build(BuildContext context) {
    final mostrarTreino = PermissionService.has(staffAtual, Permission.prescricaoTreinos);

    return DefaultTabController(
      length: mostrarTreino ? 5 : 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(aluno.nome, overflow: TextOverflow.ellipsis),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              const Tab(text: 'Dados'),
              const Tab(text: 'Anamnese'),
              const Tab(text: 'Termo'),
              const Tab(text: 'Avaliações'),
              if (mostrarTreino) const Tab(text: 'Treinos'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
            DadosTab(
              aluno: aluno,
              alunoService: alunoService,
              storageService: storageService,
              staffAtual: staffAtual,
            ),
            AnamneseTab(uid: aluno.uid, alunoService: alunoService),
            TermoTab(aluno: aluno, alunoService: alunoService, staffAtual: staffAtual),
            AvaliacoesTab(uid: aluno.uid, alunoService: alunoService),
            if (mostrarTreino)
              TreinosTab(
                uid: aluno.uid,
                alunoService: alunoService,
                staffAtual: staffAtual,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
