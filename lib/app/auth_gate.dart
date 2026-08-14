import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/welcome_screen.dart';
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

/// Decide entre a tela de login e a tela de boas-vindas com base no
/// estado de autenticacao atual do Firebase.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
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
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return LoginScreen(authService: authService);
        }

        // Prepara o recebimento de notificacoes de mensalidade (permissao +
        // token FCM) assim que sabemos que ha um usuario logado — nao
        // bloqueia a navegacao pra tela de boas-vindas.
        unawaited(notificacaoService.registrarTokenDoAparelho(user.uid));

        return WelcomeScreen(
          uid: user.uid,
          authService: authService,
          userService: userService,
          alunoService: alunoService,
          caixaService: caixaService,
          cargoService: cargoService,
          contaPagarService: contaPagarService,
          funcionarioService: funcionarioService,
          notificacaoService: notificacaoService,
          planoService: planoService,
          produtoService: produtoService,
          storageService: storageService,
        );
      },
    );
  }
}
