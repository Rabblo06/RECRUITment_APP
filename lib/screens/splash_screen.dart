import 'package:flutter/material.dart';
import '../services/session.dart';
import 'login_screen.dart';
import 'staff_dashboard_screen.dart';
import 'biometric_lock_screen.dart';
import 'auth_gate_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    final token = await Session.token();
    final role = await Session.role();

    // If no session → login
    if (token == null || role != "staff") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    // ✅ Session exists → ALWAYS ask login gate
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AuthGateScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF7F3FB),
      body: Center(
        child: Text(
          "Adolphus",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
