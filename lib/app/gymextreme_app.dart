import 'package:flutter/material.dart';

import '../services/aluno_service.dart';
import '../services/auth_service.dart';
import '../services/cargo_service.dart';
import '../services/exercicio_service.dart';
import '../services/funcionario_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';

class GymExtremeApp extends StatelessWidget {
  const GymExtremeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userService = UserService();
    final alunoService = AlunoService();
    final exercicioService = ExercicioService();
    final cargoService = CargoService();
    final funcionarioService = FuncionarioService();

    return MaterialApp(
      title: 'GymExtreme',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AuthGate(
        authService: authService,
        userService: userService,
        alunoService: alunoService,
        exercicioService: exercicioService,
        cargoService: cargoService,
        funcionarioService: funcionarioService,
      ),
    );
  }
}
