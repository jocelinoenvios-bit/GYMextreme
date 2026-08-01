import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import 'auth_gate.dart';

class GymExtremeApp extends StatelessWidget {
  const GymExtremeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final userService = UserService();

    return MaterialApp(
      title: 'GymExtreme',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: AuthGate(authService: authService, userService: userService),
    );
  }
}
