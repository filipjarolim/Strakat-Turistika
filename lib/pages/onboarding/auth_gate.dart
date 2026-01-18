import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../pages/login_page.dart';
import 'permission_gate.dart';

/// Wraps the application to enforce authentication.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if user is logged in using the service static getter
    if (AuthService.isLoggedIn) {
      return const PermissionGate();
    } else {
      return const LoginPage();
    }
  }
}
