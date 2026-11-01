import 'package:flutter/material.dart';

import '../../models/aluno.dart';
import '../../models/app_user.dart';
import '../../models/permission.dart';
import '../../services/acesso_service.dart';
import '../../services/aluno_service.dart';
import '../../services/permission_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/status_acesso.dart';
import '../../widgets/foto_aluno_image.dart';
import '../../widgets/premium.dart';
import 'tabs/anamnese_tab.dart';
import 'tabs/avaliacoes_tab.dart';
import 'tabs/dados_tab.dart';
import 'tabs/frequencia_tab.dart';
import 'tabs/termo_tab.dart';
import 'tabs/treinos_tab.dart';

/// Ficha do aluno: um cabeçalho (foto, nome, e-mail e situação da
/// mensalidade) e as partes da ficha em cards, no mesmo visual da tela
/// inicial. Cada card abre só aquela parte, numa tela própria — antes a
/// ficha abria direto em "Dados", com as outras partes em abas.
///
/// Treinos, Anamnese e Avaliações aparecem pra qualquer staff; criar ou
/// editar dentro delas exige a permissão específica (ver cada tela, e
/// reforçado em `firestore.rules`). Frequência é a única cuja
/// visibilidade depende de permissão (`Permission.frequencia`).
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

  bool get _temFrequencia =>
      PermissionService.has(staffAtual, Permission.frequencia);

  void _abrir(BuildContext context, String titulo, Widget conteudo) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ParteDaFichaScreen(
          titulo: titulo,
          alunoNome: aluno.nome,
          child: conteudo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      CardPremium(
        desenho: Desenhos.cartao,
        rotulo: 'Dados\npessoais',
        onTap: () => _abrir(
          context,
          'Dados pessoais',
          DadosTab(
            aluno: aluno,
            alunoService: alunoService,
            storageService: storageService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      CardPremium(
        desenho: Desenhos.anamnese,
        rotulo: 'Anamnese',
        onTap: () => _abrir(
          context,
          'Anamnese',
          AnamneseTab(
            uid: aluno.uid,
            alunoService: alunoService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      CardPremium(
        desenho: Desenhos.escudo,
        rotulo: 'Termo',
        onTap: () => _abrir(
          context,
          'Termo',
          TermoTab(
            aluno: aluno,
            alunoService: alunoService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      CardPremium(
        desenho: Desenhos.medidas,
        rotulo: 'Avaliações',
        onTap: () => _abrir(
          context,
          'Avaliações',
          AvaliacoesTab(
            uid: aluno.uid,
            alunoService: alunoService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      CardPremium(
        desenho: Desenhos.ficha,
        rotulo: 'Treinos',
        onTap: () => _abrir(
          context,
          'Treinos',
          TreinosTab(
            uid: aluno.uid,
            alunoService: alunoService,
            staffAtual: staffAtual,
          ),
        ),
      ),
      if (_temFrequencia)
        CardPremium(
          desenho: Desenhos.evolucao,
          rotulo: 'Frequência',
          onTap: () => _abrir(
            context,
            'Frequência',
            FrequenciaTab(
              uid: aluno.uid,
              alunoService: alunoService,
              acessoService: acessoService,
              staffAtual: staffAtual,
            ),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(aluno.nome, overflow: TextOverflow.ellipsis)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            StreamBuilder<Aluno?>(
              stream: alunoService.watchAluno(aluno.uid),
              builder: (context, snapshot) =>
                  _Cabecalho(aluno: aluno, ficha: snapshot.data),
            ),
            const SizedBox(height: 24),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.94,
              children: cards,
            ),
          ],
        ),
      ),
    );
  }
}

/// Foto com aro dourado, nome, e-mail e a situação da mensalidade.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.aluno, required this.ficha});

  final AppUser aluno;
  final Aluno? ficha;

  (String, Color) _situacao() {
    final f = ficha;
    if (f != null && !f.ativo) return ('Inativo', AppColors.textSecondary);
    final status = calcularStatusAcesso(
      proximoVencimento: f?.proximoVencimento,
    );
    switch (status.status) {
      case StatusMensalidade.emDia:
        return status.diasParaVencimento == 0
            ? ('Vence hoje', AppColors.gold)
            : ('Em dia', const Color(0xFF4CAF6D));
      case StatusMensalidade.tolerancia:
        return ('Vencida', AppColors.gold);
      case StatusMensalidade.bloqueado:
        return ('Bloqueado · mensalidade vencida', AppColors.error);
      case StatusMensalidade.semRegistro:
        return ('Sem vencimento', AppColors.textSecondary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = imagemDaFotoAluno(ficha?.fotoUrl);
    final inicial = aluno.nome.trim().isEmpty
        ? '?'
        : aluno.nome.trim()[0].toUpperCase();
    final (texto, cor) = _situacao();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFC9941A), width: 2),
            boxShadow: const [
              BoxShadow(color: Color(0x59FFBE28), blurRadius: 14),
            ],
          ),
          child: CircleAvatar(
            radius: 46,
            backgroundColor: const Color(0xFF1A1A1A),
            backgroundImage: foto,
            onBackgroundImageError: foto != null ? (_, _) {} : null,
            child: foto == null
                ? Text(
                    inicial,
                    style: const TextStyle(
                      color: OuroPremium.texto,
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          aluno.nome,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          aluno.email,
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            texto,
            style: TextStyle(
              color: cor,
              fontWeight: FontWeight.bold,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

/// Uma parte da ficha (Dados, Anamnese...) em tela cheia.
class _ParteDaFichaScreen extends StatelessWidget {
  const _ParteDaFichaScreen({
    required this.titulo,
    required this.alunoNome,
    required this.child,
  });

  final String titulo;
  final String alunoNome;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(titulo, overflow: TextOverflow.ellipsis),
            Text(
              alunoNome,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(child: child),
    );
  }
}
