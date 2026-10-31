import 'package:flutter/material.dart';

import '../services/aluno_service.dart';
import '../services/auth_service.dart';
import '../services/caixa_service.dart';
import '../services/cargo_service.dart';
import '../services/conta_pagar_service.dart';
import '../services/funcionario_service.dart';
import '../services/notificacao_service.dart';
import '../services/plano_service.dart';
import '../services/produto_service.dart';
import '../services/storage_service.dart';
import '../services/user_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/tema_controller.dart';
import 'auth_gate.dart';

class GymExtremeApp extends StatefulWidget {
  const GymExtremeApp({super.key, this.temaInicial = TemaApp.escuro});

  /// Tema lido da preferência salva antes do `runApp` (ver `main`), pra
  /// o app já abrir no tema certo em vez de piscar o escuro primeiro.
  final TemaApp temaInicial;

  @override
  State<GymExtremeApp> createState() => _GymExtremeAppState();
}

class _GymExtremeAppState extends State<GymExtremeApp> {
  late final TemaController _temaController;

  // Criados uma vez só: a árvore inteira é reconstruída a cada troca de
  // tema, e refazer os serviços a cada rebuild seria desperdício.
  final _authService = AuthService();
  final _userService = UserService();
  final _alunoService = AlunoService();
  final _caixaService = CaixaService();
  final _cargoService = CargoService();
  final _contaPagarService = ContaPagarService();
  final _funcionarioService = FuncionarioService();
  final _notificacaoService = NotificacaoService();
  final _planoService = PlanoService();
  final _produtoService = ProdutoService();
  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    _temaController = TemaController(inicial: widget.temaInicial);
  }

  @override
  void dispose() {
    _temaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TemaEscopo(
      controller: _temaController,
      child: AnimatedBuilder(
        animation: _temaController,
        builder: (context, _) => MaterialApp(
          title: 'GymXtreme',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.de(_temaController.tema),
          home: AuthGate(
            authService: _authService,
            userService: _userService,
            alunoService: _alunoService,
            caixaService: _caixaService,
            cargoService: _cargoService,
            contaPagarService: _contaPagarService,
            funcionarioService: _funcionarioService,
            notificacaoService: _notificacaoService,
            planoService: _planoService,
            produtoService: _produtoService,
            storageService: _storageService,
          ),
        ),
      ),
    );
  }
}
