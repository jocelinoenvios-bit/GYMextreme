import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import '../screens/welcome_screen.dart';
import '../services/aluno_service.dart';
import '../services/auth_service.dart';
import '../services/exercicio_service.dart';
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
    required this.exercicioService,
  });

  final AuthService authService;
  final UserService userService;
  final AlunoService alunoService;
  final ExercicioService exercicioService;

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

        return WelcomeScreen(
          uid: user.uid,
          authService: authService,
          userService: userService,
          alunoService: alunoService,
          exercicioService: exercicioService,
        );
      },
    );
  }
}
