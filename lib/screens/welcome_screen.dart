import 'package:flutter/material.dart';

import '../models/aluno.dart';
import '../models/app_user.dart';
import '../models/mensagem.dart';
import '../models/permission.dart';
import '../models/user_role.dart';
import '../services/aluno_service.dart';
import '../services/auth_service.dart';
import '../services/caixa_service.dart';
import '../services/cargo_service.dart';
import '../services/conta_pagar_service.dart';
import '../services/funcionario_service.dart';
import '../services/notificacao_service.dart';
import '../services/permission_service.dart';
import '../services/plano_service.dart';
import '../services/produto_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../utils/status_acesso.dart';
import '../theme/tema_controller.dart';
import '../widgets/gymextreme_logo.dart';
import '../widgets/texto_contornado.dart';
import 'alunos/alunos_list_screen.dart';
import 'alunos/enviar_mensagem_screen.dart';
import 'area_aluno/meus_dados_aluno_screen.dart';
import 'area_aluno/meus_treinos_screen.dart';
import 'area_aluno/mensagens_screen.dart';
import 'area_aluno/minha_anamnese_screen.dart';
import 'area_aluno/minha_evolucao_screen.dart';
import 'area_aluno/minha_ficha_screen.dart';
import 'area_aluno/minhas_medidas_screen.dart';
import 'caixa/caixa_screen.dart';
import 'contas_pagar/contas_pagar_list_screen.dart';
import 'contas_receber/contas_receber_list_screen.dart';
import 'exercicios/exercicios_list_screen.dart';
import 'funcionarios/funcionarios_list_screen.dart';
import 'matriculas/matriculas_list_screen.dart';
import 'planos/planos_list_screen.dart';
import 'produtos/produtos_list_screen.dart';
import 'relatorios/dashboard_screen.dart';

/// Tela pos-login: cada botao aparece de acordo com as permissoes
/// individuais do usuario logado (ver `PermissionService`), nao mais um
/// unico bloco "staff vs aluno". As demais telas de cada perfil chegam nos
/// proximos modulos.
///
/// O aluno tem uma tela inicial própria (`_buildHomeAluno`), redesenhada
/// pra ficar mais parecida com um app de rede social/menu de celular —
/// staff continua com a tela genérica de sempre (`_scaffoldGenerico` +
/// `_buildConteudoPadrao`).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({
    super.key,
    required this.uid,
    required this.authService,
    required this.userService,
    required this.alunoService,
    required this.caixaService,
    required this.cargoService,
    required this.contaPagarService,
    required this.funcionarioService,
    required this.notificacaoService,
    required this.planoService,
    required this.produtoService,
    required this.storageService,
  });

  final String uid;
  final AuthService authService;
  final UserService userService;
  final AlunoService alunoService;
  final CaixaService caixaService;
  final CargoService cargoService;
  final ContaPagarService contaPagarService;
  final FuncionarioService funcionarioService;
  final NotificacaoService notificacaoService;
  final PlanoService planoService;
  final ProdutoService produtoService;
  final StorageService storageService;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: userService.watchUser(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _scaffoldGenerico(context, const Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return _scaffoldGenerico(
            context,
            Center(
              child: Text(
                'Erro ao carregar seu perfil.',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return _scaffoldGenerico(
            context,
            Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Login efetuado, mas nao encontramos seu cadastro na '
                  'colecao "usuarios" do Firestore. Peça para a '
                  'administracao criar seu perfil com o campo "role".',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ),
          );
        }

        if (user.role == UserRole.aluno) {
          return StreamBuilder<Aluno?>(
            stream: alunoService.watchAluno(uid),
            builder: (context, alunoSnapshot) {
              final status = calcularStatusAcesso(
                proximoVencimento: alunoSnapshot.data?.proximoVencimento,
              );
              if (status.status == StatusMensalidade.bloqueado) {
                return _scaffoldGenerico(context, const _AcessoSuspenso());
              }
              return _buildHomeAluno(context, user, alunoSnapshot.data);
            },
          );
        }

        return _scaffoldGenerico(context, _buildConteudoPadrao(context, user), user: user);
      },
    );
  }

  /// Scaffold "de sempre" (logo + botão de sair na AppBar) — usado pro
  /// staff inteiro e pelos estados genéricos (carregando/erro/bloqueado)
  /// de qualquer papel, inclusive aluno. Com [user] informado (telas de
  /// staff já carregadas), ganha a engrenagem de configurações no canto
  /// superior esquerdo — nome/e-mail saem da tela principal e vão pra lá,
  /// mesmo padrão já usado na tela inicial do aluno. Sem [user] (telas de
  /// carregando/erro/bloqueado), não tem o que mostrar nas configurações
  /// ainda, então a engrenagem fica de fora.
  Scaffold _scaffoldGenerico(BuildContext context, Widget body, {AppUser? user}) {
    return Scaffold(
      appBar: AppBar(
        leading: user == null
            ? null
            : IconButton(
                tooltip: 'Configurações',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => _abrirConfiguracoes(context, user),
              ),
        title: const GymExtremeLogo(compact: true),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => _sair(),
          ),
        ],
      ),
      body: SafeArea(child: body),
    );
  }

  Future<void> _sair() async {
    // Remove o token FCM deste aparelho ANTES de sair — depois do
    // signOut() o Firestore ja nao autoriza mais essa escrita (regra
    // exige request.auth.uid == uid).
    await notificacaoService.removerTokenDoAparelho(uid);
    await authService.signOut();
  }

  /// Tela inicial redesenhada do aluno: foto grande no canto superior
  /// esquerdo da AppBar, saudação com o nome completo, os 2 atalhos
  /// principais (Biblioteca/Meus treinos) e as funções que antes ficavam
  /// escondidas atrás de "Meu Perfil" agora como ícones quadrados, estilo
  /// menu de celular. Nome/e-mail e "Sair" saem da tela principal e vão
  /// pra dentro do botão de engrenagem (canto inferior direito).
  Widget _buildHomeAluno(BuildContext context, AppUser user, Aluno? aluno) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: _AvatarAluno(nome: user.nome, fotoUrl: aluno?.fotoUrl, raio: 20),
        ),
        leadingWidth: 56,
        title: const GymExtremeLogo(compact: true),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Configurações',
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.black,
        onPressed: () => _abrirConfiguracoes(context, user),
        child: const Icon(Icons.settings_outlined),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Icon(_iconFor(user.role), color: AppColors.gold, size: 48),
                  const SizedBox(height: 14),
                  TextoContornado(
                    'Bem-vindo, ${user.nome}',
                    textAlign: TextAlign.center,
                    estilo:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.gold,
                          fontWeight: FontWeight.bold,
                        ) ??
                        const TextStyle(),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExerciciosListScreen()),
                ),
                icon: const Icon(Icons.fitness_center_outlined),
                label: const Text('BIBLIOTECA DE EXERCÍCIOS'),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MeusTreinosScreen(uid: uid, alunoService: alunoService),
                  ),
                ),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('MEUS TREINOS'),
              ),
              const SizedBox(height: 28),
              TextoContornado(
                'MEU PERFIL',
                espessura: 1.4,
                estilo: TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.85,
                children: [
                  _TileMenuPerfil(
                    icone: Icons.badge_outlined,
                    rotulo: 'Dados\npessoais',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MeusDadosAlunoScreen(
                          usuario: user,
                          uid: uid,
                          alunoService: alunoService,
                        ),
                      ),
                    ),
                  ),
                  _TileMenuPerfil(
                    icone: Icons.calendar_view_week_outlined,
                    rotulo: 'Minha\nficha',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MinhaFichaScreen(uid: uid, alunoService: alunoService),
                      ),
                    ),
                  ),
                  _TileMenuPerfil(
                    icone: Icons.straighten_outlined,
                    rotulo: 'Minhas\nmedidas',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MinhasMedidasScreen(uid: uid, alunoService: alunoService),
                      ),
                    ),
                  ),
                  _TileMenuPerfil(
                    icone: Icons.assignment_outlined,
                    rotulo: 'Minha\nanamnese',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MinhaAnamneseScreen(uid: uid, alunoService: alunoService),
                      ),
                    ),
                  ),
                  _TileMenuPerfil(
                    icone: Icons.show_chart_outlined,
                    rotulo: 'Minha\nevolução',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            MinhaEvolucaoScreen(uid: uid, alunoService: alunoService),
                      ),
                    ),
                  ),
                  // Reaproveita o mesmo stream que a tela de mensagens
                  // usa, em vez de uma consulta só de contagem: o volume
                  // de avisos por aluno é pequeno e assim o selo zera
                  // junto com a leitura, sem um segundo listener.
                  StreamBuilder<List<Mensagem>>(
                    stream: alunoService.watchMensagens(uid),
                    builder: (context, snapshot) {
                      final naoLidas = (snapshot.data ?? const <Mensagem>[])
                          .where((mensagem) => !mensagem.lida)
                          .length;
                      return _TileMenuPerfil(
                        icone: Icons.chat_bubble_outline,
                        rotulo: 'Mensagens',
                        naoLidas: naoLidas,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MensagensScreen(
                              uid: uid,
                              alunoService: alunoService,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Painel de configurações (nome completo, e-mail, sair) — aberto pelo
  /// botão de engrenagem da tela inicial do aluno.
  void _abrirConfiguracoes(BuildContext context, AppUser user) {
    // Pego aqui, e não lá dentro: o `builder` roda numa rota nova, e
    // assim o seletor de tema some sozinho num teste que monte a tela
    // sem o app em volta (onde não existe TemaEscopo).
    final temaController = TemaEscopo.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextoContornado(
                  'Configurações',
                  espessura: 1.6,
                  estilo: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  user.nome,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(user.email, style: TextStyle(color: AppColors.textSecondary)),
                if (temaController != null) ...[
                  const SizedBox(height: 24),
                  Divider(color: AppColors.surfaceHigh, height: 1),
                  const SizedBox(height: 20),
                  Text(
                    'APARÊNCIA',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SeletorTema(
                    controller: temaController,
                    // Fecha o painel junto: o próprio painel foi montado
                    // com as cores do tema antigo (o fundo dele vem de um
                    // parâmetro do showModalBottomSheet, não reconstrói),
                    // e fechando o usuário já vê a tela inteira no tema
                    // novo.
                    aoTrocar: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _sair();
                    },
                    icon: Icon(Icons.logout, color: AppColors.error),
                    label: Text('SAIR', style: TextStyle(color: AppColors.error)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.error),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConteudoPadrao(BuildContext context, AppUser user) {
    // SingleChildScrollView (em vez de Center) porque a lista de botões
    // varia com as permissões do usuário — um ADM com todas as permissões
    // tem 9 botões, que não cabem na tela em muitos aparelhos. Sem
    // rolagem aqui, o conteúdo mais embaixo (ex.: "GERENCIAR
    // FUNCIONÁRIOS") ficava cortado ou disparava overflow.
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconFor(user.role), color: AppColors.gold, size: 56),
            const SizedBox(height: 16),
            TextoContornado(
              'Bem-vindo, ${user.role.welcomeLabel}',
              textAlign: TextAlign.center,
              estilo:
                  Theme.of(context).textTheme.headlineMedium ??
                  const TextStyle(),
            ),
            const SizedBox(height: 28),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                if (PermissionService.has(user, Permission.relatorios))
                  _TileMenuPerfil(
                    icone: Icons.dashboard_outlined,
                    rotulo: 'Painel e\nrelatórios',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => DashboardScreen(
                          alunoService: alunoService,
                          caixaService: caixaService,
                          contaPagarService: contaPagarService,
                          produtoService: produtoService,
                          staffAtual: user,
                        ),
                      ),
                    ),
                  ),
                if (PermissionService.has(user, Permission.gerenciarAlunos))
                  _TileMenuPerfil(
                    icone: Icons.groups_outlined,
                    rotulo: 'Gerenciar\nalunos',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AlunosListScreen(
                          alunoService: alunoService,
                          storageService: storageService,
                          staffAtual: user,
                        ),
                      ),
                    ),
                  ),
                if (PermissionService.has(user, Permission.chat))
                  _TileMenuPerfil(
                    icone: Icons.send_outlined,
                    rotulo: 'Enviar\nmensagem',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EnviarMensagemScreen(
                          alunoService: alunoService,
                          staffAtual: user,
                        ),
                      ),
                    ),
                  ),
                if (PermissionService.has(user, Permission.acessarPlanos))
                  _TileMenuPerfil(
                    icone: Icons.card_membership_outlined,
                    rotulo: 'Planos',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlanosListScreen(
                          planoService: planoService,
                          staffAtual: user,
                        ),
                      ),
                    ),
                  ),
                if (PermissionService.has(user, Permission.matriculas))
                  _TileMenuPerfil(
                    icone: Icons.assignment_ind_outlined,
                    rotulo: 'Matrículas',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MatriculasListScreen(
                          alunoService: alunoService,
                          planoService: planoService,
                          storageService: storageService,
                          staffAtual: user,
                        ),
                      ),
                    ),
                  ),
                if (PermissionService.has(user, Permission.acessarContasReceber))
                  _TileMenuPerfil(
                    icone: Icons.receipt_long_outlined,
                    rotulo: 'Contas a\nreceber',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ContasReceberListScreen(
                          alunoService: alunoService,
                          caixaService: caixaService,
                          staffAtual: user,
                        ),
                      ),
                    ),
                  ),
                if (PermissionService.has(user, Permission.acessarControleCaixa))
                  _TileMenuPerfil(
                    icone: Icons.point_of_sale_outlined,
                    rotulo: 'Controle de\ncaixa',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => CaixaScreen(
                          caixaService: caixaService,
                          staffAtual: user,
                        ),
                      ),
                    ),
                  ),
                if (PermissionService.has(user, Permission.acessarContasPagar))
                  _TileMenuPerfil(
                    icone: Icons.request_quote_outlined,
                    rotulo: 'Contas a\npagar',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ContasPagarListScreen(
                          contaPagarService: contaPagarService,
                          caixaService: caixaService,
                          staffAtual: user,
                        ),
                      ),
                    ),
                  ),
                if (PermissionService.has(user, Permission.acessarProdutos))
                  _TileMenuPerfil(
                    icone: Icons.inventory_2_outlined,
                    rotulo: 'Produtos',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProdutosListScreen(
                          produtoService: produtoService,
                          staffAtual: user,
                        ),
                      ),
                    ),
                  ),
                if (PermissionService.has(user, Permission.bibliotecaExercicios))
                  _TileMenuPerfil(
                    icone: Icons.fitness_center_outlined,
                    rotulo: 'Biblioteca de\nexercícios',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ExerciciosListScreen()),
                    ),
                  ),
                if (PermissionService.has(user, Permission.gerenciarFuncionarios))
                  _TileMenuPerfil(
                    icone: Icons.badge_outlined,
                    rotulo: 'Gerenciar\nfuncionários',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FuncionariosListScreen(
                          funcionarioService: funcionarioService,
                          cargoService: cargoService,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(UserRole role) {
    switch (role) {
      case UserRole.adm:
        return Icons.admin_panel_settings_outlined;
      case UserRole.personal:
        return Icons.sports_gymnastics_outlined;
      case UserRole.funcionario:
        return Icons.badge_outlined;
      case UserRole.aluno:
        return Icons.fitness_center_outlined;
    }
  }
}

/// Foto do aluno (ou círculo com a inicial do nome, se não tiver foto
/// cadastrada) — usada no canto superior esquerdo da AppBar da tela
/// inicial do aluno.
class _AvatarAluno extends StatelessWidget {
  const _AvatarAluno({required this.nome, required this.fotoUrl, required this.raio});

  final String nome;
  final String? fotoUrl;
  final double raio;

  @override
  Widget build(BuildContext context) {
    final inicial = nome.trim().isEmpty ? '?' : nome.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: raio,
      backgroundColor: AppColors.surfaceHigh,
      backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl!) : null,
      child: fotoUrl == null
          ? Text(
              inicial,
              style: TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: raio * 0.8,
              ),
            )
          : null,
    );
  }
}

/// Um ícone quadrado de cantos arredondados + rótulo — estilo menu de
/// celular, substitui o antigo card único "MEU PERFIL" (ver
/// `MeuPerfilScreen`, cujos 5 destinos agora são acessados direto daqui).
class _TileMenuPerfil extends StatelessWidget {
  const _TileMenuPerfil({
    required this.icone,
    required this.rotulo,
    required this.onTap,
    this.naoLidas = 0,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;

  /// Quantidade no selo do canto. Zero esconde o selo.
  final int naoLidas;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Column(
        children: [
          // Expanded (não AspectRatio) de propósito: a célula do
          // GridView tem altura FIXA (childAspectRatio), então insistir
          // num quadrado perfeito baseado na largura da célula podia
          // sobrar pouco espaço pra legenda de 2 linhas e estourar por
          // baixo (bug real, visto em aparelho físico) — Expanded
          // sempre ocupa só o espaço que sobra depois da legenda, nunca
          // estoura, não importa o tamanho da tela ou da fonte.
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icone, color: AppColors.gold, size: 26),
                ),
                if (naoLidas > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: AppColors.surfaceHigh, width: 2),
                      ),
                      child: Text(
                        naoLidas > 9 ? '9+' : '$naoLidas',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textPrimary, fontSize: 11.5, height: 1.2),
          ),
        ],
      ),
    );
  }
}

/// Tela mostrada no lugar do conteudo normal quando a mensalidade do aluno
/// passou dos dias de tolerancia — mesmo texto usado na notificacao
/// (`mensagemNotificacaoMensalidade`), sempre visivel enquanto bloqueado
/// (nao so no primeiro dia).
class _AcessoSuspenso extends StatelessWidget {
  const _AcessoSuspenso();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, color: AppColors.error, size: 56),
            const SizedBox(height: 16),
            Text(
              'Acesso suspenso',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 12),
            Text(
              'Sua mensalidade permanece em atraso. Seu acesso ao '
              'aplicativo e à academia foi bloqueado até a regularização '
              'do pagamento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 8),
            Text(
              'Procure a recepção para regularizar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// As duas opções de tema, cada uma com uma miniatura da tela — mais
/// direto que um interruptor "modo escuro", que não diz como o claro vai
/// ficar.
class _SeletorTema extends StatelessWidget {
  const _SeletorTema({required this.controller, required this.aoTrocar});

  final TemaController controller;
  final VoidCallback aoTrocar;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _OpcaoTema(
            rotulo: 'Escuro',
            icone: Icons.dark_mode_outlined,
            tema: TemaApp.escuro,
            selecionado: controller.tema == TemaApp.escuro,
            fundoMiniatura: PaletaApp.escura.black,
            traco: PaletaApp.escura.surfaceHigh,
            controller: controller,
            aoTrocar: aoTrocar,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _OpcaoTema(
            rotulo: 'Claro',
            icone: Icons.light_mode_outlined,
            tema: TemaApp.claro,
            selecionado: controller.tema == TemaApp.claro,
            fundoMiniatura: PaletaApp.clara.black,
            traco: PaletaApp.clara.surfaceHigh,
            controller: controller,
            aoTrocar: aoTrocar,
          ),
        ),
      ],
    );
  }
}

class _OpcaoTema extends StatelessWidget {
  const _OpcaoTema({
    required this.rotulo,
    required this.icone,
    required this.tema,
    required this.selecionado,
    required this.fundoMiniatura,
    required this.traco,
    required this.controller,
    required this.aoTrocar,
  });

  final String rotulo;
  final IconData icone;
  final TemaApp tema;
  final bool selecionado;

  /// Cores fixas da paleta que a opção representa, não da paleta ativa —
  /// é uma amostra do tema, tem que se parecer com ele mesmo quando o
  /// outro está ligado.
  final Color fundoMiniatura;
  final Color traco;

  final TemaController controller;
  final VoidCallback aoTrocar;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: selecionado
          ? null
          : () {
              aoTrocar();
              controller.trocar(tema);
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selecionado ? AppColors.gold : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: fundoMiniatura,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LinhaMiniatura(cor: AppColors.gold, largura: 0.6),
                  const SizedBox(height: 5),
                  _LinhaMiniatura(cor: traco, largura: 0.95),
                  const SizedBox(height: 4),
                  _LinhaMiniatura(cor: traco, largura: 0.75),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icone,
                  size: 15,
                  color: selecionado ? AppColors.gold : AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selecionado
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LinhaMiniatura extends StatelessWidget {
  const _LinhaMiniatura({required this.cor, required this.largura});

  final Color cor;

  /// Fração da largura disponível, pra miniatura parecer um texto.
  final double largura;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: largura,
      child: Container(
        height: 4,
        decoration: BoxDecoration(
          color: cor,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }
}
