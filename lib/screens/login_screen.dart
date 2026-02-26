import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:local_auth/local_auth.dart';

import '../services/api.dart';
import '../services/session.dart';
import 'biometric_setup_screen.dart';

import 'staff_dashboard_screen.dart';
import '../services/session.dart';
import '../services/notifications_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool loading = false;
  bool obscure = true;
  String? error;

  // ✅ Android emulator URL
  Future<void> _login() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final username = usernameCtrl.text.trim();
      final password = passwordCtrl.text.trim();

      if (username.isEmpty || password.isEmpty) {
        throw Exception("Username and password are required");
      }

      final res = await http.post(
        Uri.parse("${Api.baseUrl}/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"username": username, "password": password}),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode != 200) {
        throw Exception(data["message"] ?? "Login failed");
      }

      // ✅ Expecting: { token: "...", user: {...} }
      final token = data["token"];
      final user = data["user"];
      final role = (user is Map) ? user["role"] : null;

      if (token == null || role == null) {
        throw Exception("Login response missing token/role. Fix backend JSON.");
      }

      // ✅ Extract staffId from backend user object
      final staffId = (user is Map)
          ? (user["_id"] ?? user["id"] ?? user["userId"] ?? "").toString()
          : "";

      // ✅ Better staff name to display
      final staffName = (user is Map)
          ? (user["fullName"] ?? user["name"] ?? user["username"] ?? username)
                .toString()
          : username;

      if (role == "staff" && staffId.isEmpty) {
        throw Exception(
          "Login response missing user id (_id). Fix backend JSON.",
        );
      }

      if (!mounted) return;

      if (role == "admin") {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Admin: Use Desktop Admin Portal to create staff ✅"),
          ),
        );
        return; // stay on login
      }

      await NotificationsService.init(jwtToken: token);
      // ✅ Save session (so splash can auto-login)
      await Session.saveLogin(
        token: token,
        name: staffName,
        role: role,
        staffId: staffId,
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StaffDashboardScreen(
            token: token,
            staffName: staffName,
            staffId: staffId,
          ),
        ),
      );

      // ✅ staff -> go to staff home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => StaffDashboardScreen(
            token: token,
            staffName: staffName,
            staffId: staffId,
          ),
        ),
      );
    } catch (e) {
      setState(() => error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFEFEFF3); // smooth single color like your prototype
    const cardRadius = 18.0;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo (uses asset if you add it, otherwise shows fallback icon)
                Image.asset(
                  "assets/icon.png",
                  height: 58,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.search,
                    size: 54,
                    color: Color(0xFF555A62),
                  ),
                ),
                const SizedBox(height: 10),

                const Text(
                  "Adolphus",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5A5F66),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 22),

                // White card
                Container(
                  width: 320,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(cardRadius),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _InputRow(
                        icon: Icons.person,
                        controller: usernameCtrl,
                        hint: "Username",
                        obscure: false,
                        suffix: null,
                      ),
                      const SizedBox(height: 10),
                      _DividerLine(),
                      const SizedBox(height: 10),

                      _InputRow(
                        icon: Icons.lock,
                        controller: passwordCtrl,
                        hint: "Password",
                        obscure: obscure,
                        suffix: IconButton(
                          onPressed: () => setState(() => obscure = !obscure),
                          icon: Icon(
                            obscure ? Icons.visibility : Icons.visibility_off,
                            size: 18,
                            color: const Color(0xFF8E939A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DividerLine(),
                      const SizedBox(height: 16),

                      // Login button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: loading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E1F24),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: loading
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  "Login",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                if (error != null)
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

class _DividerLine extends StatelessWidget {
  const _DividerLine();

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: const Color(0xFFE6E7EB));
  }
}

class _InputRow extends StatelessWidget {
  final IconData icon;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;

  const _InputRow({
    required this.icon,
    required this.controller,
    required this.hint,
    required this.obscure,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF8E939A)),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2A2D33),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFFB0B4BA),
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        if (suffix != null) suffix!,
      ],
    );
  }
}
