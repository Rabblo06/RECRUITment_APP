import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'staff_dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool loading = false;
  String? error;

  // ✅ Android emulator URL
  static const String baseUrl = "http://10.0.2.2:4000";

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
        Uri.parse("$baseUrl/auth/login"),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Login",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: usernameCtrl,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              decoration: const InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: loading ? null : _login,
                child: loading
                    ? const CircularProgressIndicator()
                    : const Text("Login"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
