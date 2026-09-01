import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/aluno_service.dart';
import '../../services/storage_service.dart';
import 'tabs/anamnese_tab.dart';
import 'tabs/avaliacoes_tab.dart';
import 'tabs/dados_tab.dart';
import 'tabs/termo_tab.dart';
import 'tabs/treinos_tab.dart';

/// Ficha completa do aluno, em abas: dados de cadastro, anamnese, termo
/// de responsabilidade, historico de avaliacoes fisicas e fichas de
/// treino — a aba de Treinos é sempre visível pra qualquer staff, sem
/// exigir a permissão `prescricaoTreinos` (decisão explícita: só a
/// visibilidade da aba foi liberada; criar/editar treino continua
/// exigindo `criarTreinos`/`editarTreinos`, ver `TreinosTab`).
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
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text(aluno.nome, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Dados'),
              Tab(text: 'Anamnese'),
              Tab(text: 'Termo'),
              Tab(text: 'Avaliações'),
              Tab(text: 'Treinos'),
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
