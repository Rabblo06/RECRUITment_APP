import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../services/session.dart';
import 'login_screen.dart';
import 'staff_dashboard_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  final _auth = LocalAuthentication();
  bool loading = false;
  String? error;

  Future<void> _goDashboard() async {
    final token = await Session.token();
    final name = await Session.name();
    final staffId = await Session.staffId();

    if (!mounted) return;

    // If anything missing, force password login
    if (token == null || name == null || staffId == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StaffDashboardScreen(
          token: token,
          staffName: name,
          staffId: staffId,
        ),
      ),
    );
  }

  Future<void> _biometricSignIn() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      // small delay avoids some devices throwing "null check operator" internally
      await Future.delayed(const Duration(milliseconds: 250));

      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;

      if (!supported || !canCheck) {
        throw Exception("Biometric not available on this device.");
      }

      final ok = await _auth.authenticate(
        localizedReason: "Sign in to continue",
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false, // allow PIN/pattern fallback if user chooses
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;

      if (ok) {
        await _goDashboard();
      } else {
        setState(() => error = "Authentication cancelled");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _passwordSignIn() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fingerprint,
                  size: 72,
                  color: Color(0xFF2A2D33),
                ),
                const SizedBox(height: 14),
                const Text(
                  "Welcome back",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Choose how you want to sign in",
                  style: TextStyle(color: Color(0xFF5A5F66)),
                ),
                const SizedBox(height: 18),

                if (error != null) ...[
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: loading ? null : _biometricSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1F24),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      loading
                          ? "Please wait..."
                          : "Sign in with Face or Fingerprint",
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _passwordSignIn,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text("Sign in with Password"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
