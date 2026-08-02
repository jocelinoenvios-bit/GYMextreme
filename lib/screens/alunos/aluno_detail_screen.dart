import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/aluno_service.dart';
import 'tabs/anamnese_tab.dart';
import 'tabs/avaliacoes_tab.dart';
import 'tabs/dados_tab.dart';
import 'tabs/termo_tab.dart';

/// Ficha completa do aluno, em abas: dados de cadastro, anamnese, termo
/// de responsabilidade e historico de avaliacoes fisicas.
class AlunoDetailScreen extends StatelessWidget {
  const AlunoDetailScreen({
    super.key,
    required this.aluno,
    required this.alunoService,
  });

  final AppUser aluno;
  final AlunoService alunoService;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
            ],
          ),
        ),
        body: TabBarView(
          children: [
            DadosTab(aluno: aluno, alunoService: alunoService),
            AnamneseTab(uid: aluno.uid, alunoService: alunoService),
            TermoTab(aluno: aluno, alunoService: alunoService),
            AvaliacoesTab(uid: aluno.uid, alunoService: alunoService),
          ],
        ),
      ),
    );
  }
}
