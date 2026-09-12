import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/permission.dart';
import '../../services/acesso_service.dart';
import '../../services/aluno_service.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import 'tabs/anamnese_tab.dart';
import 'tabs/avaliacoes_tab.dart';
import 'tabs/dados_tab.dart';
import 'tabs/frequencia_tab.dart';
import 'tabs/termo_tab.dart';
import 'tabs/treinos_tab.dart';

/// Ficha completa do aluno, em abas: dados de cadastro, anamnese, termo
/// de responsabilidade, historico de avaliacoes fisicas, fichas de
/// treino e frequência — a aba de Treinos é sempre visível pra qualquer
/// staff, sem exigir a permissão `prescricaoTreinos` (decisão explícita:
/// só a visibilidade da aba foi liberada; criar/editar treino continua
/// exigindo `criarTreinos`/`editarTreinos`, ver `TreinosTab`). As abas
/// Anamnese e Avaliações são sempre visíveis também, mas criar/editar
/// dentro delas exige `avaliacoesFisicas` (ver `AnamneseTab`/
/// `AvaliacoesTab`) — mesmo padrão de Treinos, e reforçado em
/// `firestore.rules` (não só escondido na UI).
///
/// A aba Frequência (acesso físico + presença de treino, ver
/// `FrequenciaTab`) é a única cuja VISIBILIDADE em si depende de
/// permissão (`Permission.frequencia`) — diferente das outras, que
/// sempre aparecem e só a ação de escrever é que é restrita.
class AlunoDetailScreen extends StatelessWidget {
  AlunoDetailScreen({
    super.key,
    required this.aluno,
    required this.alunoService,
    required this.storageService,
    required this.staffAtual,
    AcessoService? acessoService,
  }) : acessoService = acessoService ?? AcessoService();

  final AppUser aluno;
  final AlunoService alunoService;
  final StorageService storageService;
  final AppUser staffAtual;
  final AcessoService acessoService;

  bool get _temFrequencia => PermissionService.has(staffAtual, Permission.frequencia);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      const Tab(text: 'Dados'),
      const Tab(text: 'Anamnese'),
      const Tab(text: 'Termo'),
      const Tab(text: 'Avaliações'),
      const Tab(text: 'Treinos'),
      if (_temFrequencia) const Tab(text: 'Frequência'),
    ];
    final paginas = [
      DadosTab(
        aluno: aluno,
        alunoService: alunoService,
        storageService: storageService,
        staffAtual: staffAtual,
      ),
      AnamneseTab(uid: aluno.uid, alunoService: alunoService, staffAtual: staffAtual),
      TermoTab(aluno: aluno, alunoService: alunoService, staffAtual: staffAtual),
      AvaliacoesTab(uid: aluno.uid, alunoService: alunoService, staffAtual: staffAtual),
      TreinosTab(uid: aluno.uid, alunoService: alunoService, staffAtual: staffAtual),
      if (_temFrequencia)
        FrequenciaTab(
          uid: aluno.uid,
          alunoService: alunoService,
          acessoService: acessoService,
          staffAtual: staffAtual,
        ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(aluno.nome, overflow: TextOverflow.ellipsis),
          bottom: TabBar(isScrollable: true, tabs: tabs),
        ),
        body: SafeArea(child: TabBarView(children: paginas)),
      ),
    );
  }
}
