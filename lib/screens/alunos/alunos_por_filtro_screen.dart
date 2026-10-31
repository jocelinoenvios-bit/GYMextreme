import 'package:flutter/material.dart';

import '../../models/aluno.dart';
import '../../models/app_user.dart';
import '../../models/permission.dart';
import '../../services/aluno_service.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/status_acesso.dart';
import '../../utils/status_operacional_aluno.dart';
import 'aluno_detail_screen.dart';
import 'enviar_mensagem_screen.dart';

/// Lista de alunos de UM grupo específico (ex.: só "Inadimplentes") —
/// aberta ao tocar num dos cards de `AlunosListScreen`. Mesmo
/// carregamento/ordenação que a lista tinha antes de virar cards, só que
/// fixado num `filtro` só (sem seletor — a escolha já foi feita na tela
/// anterior). Cada aluno aparece como um cartão (avatar, etiqueta de
/// status colorida com os dias quando fizer sentido, e-mail e um atalho
/// pra enviar mensagem), não mais uma lista simples.
class AlunosPorFiltroScreen extends StatefulWidget {
  const AlunosPorFiltroScreen({
    super.key,
    required this.filtro,
    required this.alunoService,
    required this.storageService,
    required this.staffAtual,
  });

  final FiltroStatusAluno filtro;
  final AlunoService alunoService;
  final StorageService storageService;
  final AppUser staffAtual;

  @override
  State<AlunosPorFiltroScreen> createState() => _AlunosPorFiltroScreenState();
}

class _AlunosPorFiltroScreenState extends State<AlunosPorFiltroScreen> {
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
      appBar: AppBar(title: Text(widget.filtro.label)),
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
                              style: TextStyle(color: AppColors.error),
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
                        .where(
                          (a) => alunoPassaNoFiltro(fichasPorUid[a.uid], widget.filtro),
                        )
                        .toList();

                    if (alunos.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _busca.isNotEmpty
                                ? 'Nenhum aluno encontrado para "$_busca".'
                                : 'Nenhum aluno em "${widget.filtro.label}".',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: alunos.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final aluno = alunos[index];
                        return _CartaoAluno(
                          aluno: aluno,
                          ficha: fichasPorUid[aluno.uid],
                          podeEnviarMensagem: PermissionService.has(
                            widget.staffAtual,
                            Permission.chat,
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
                          onEnviarMensagem: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => EnviarMensagemScreen(
                                alunoService: widget.alunoService,
                                staffAtual: widget.staffAtual,
                                alunoPreSelecionado: aluno,
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
}

/// Um cartão por aluno — avatar, nome, etiqueta de status colorida (com os
/// dias de atraso/inatividade quando fizer sentido), e-mail e, pra quem
/// tem a permissão `chat`, um atalho pra já abrir "Enviar mensagem" com
/// este aluno pré-selecionado.
class _CartaoAluno extends StatelessWidget {
  const _CartaoAluno({
    required this.aluno,
    required this.ficha,
    required this.podeEnviarMensagem,
    required this.onTap,
    required this.onEnviarMensagem,
  });

  final AppUser aluno;
  final Aluno? ficha;
  final bool podeEnviarMensagem;
  final VoidCallback onTap;
  final VoidCallback onEnviarMensagem;

  @override
  Widget build(BuildContext context) {
    final status = ficha != null ? calcularStatusOperacional(ficha!) : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.surfaceHigh),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: AppColors.surfaceHigh,
              child: Icon(Icons.fitness_center_outlined, color: AppColors.gold),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aluno.nome,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (status != null) ...[
                    _EtiquetaStatus(status: status, ficha: ficha!),
                    const SizedBox(height: 4),
                  ],
                  Text(
                    aluno.email,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (podeEnviarMensagem) ...[
              const SizedBox(width: 8),
              _BotaoMensagemRapida(onPressed: onEnviarMensagem),
            ],
          ],
        ),
      ),
    );
  }
}

class _EtiquetaStatus extends StatelessWidget {
  const _EtiquetaStatus({required this.status, required this.ficha});

  final StatusOperacionalAluno status;
  final Aluno ficha;

  @override
  Widget build(BuildContext context) {
    final cor = _cor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _texto(status, ficha).toUpperCase(),
        style: TextStyle(color: cor, fontSize: 10.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _texto(StatusOperacionalAluno status, Aluno ficha) {
    switch (status) {
      case StatusOperacionalAluno.ativo:
        return status.label;
      case StatusOperacionalAluno.inadimplente:
        final dias = calcularStatusAcesso(proximoVencimento: ficha.proximoVencimento).diasAtraso;
        return dias != null ? '${status.label} · $dias dias' : status.label;
      case StatusOperacionalAluno.inativo:
        final dias = diasDesdeInativacao(ficha);
        return dias != null ? '${status.label} · $dias dias' : status.label;
    }
  }

  Color _cor(StatusOperacionalAluno status) {
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

class _BotaoMensagemRapida extends StatelessWidget {
  const _BotaoMensagemRapida({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Icon(Icons.send_outlined, color: AppColors.black, size: 18),
        ),
      ),
    );
  }
}
