import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricLockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onUsePassword;

  const BiometricLockScreen({
    super.key,
    required this.onUnlocked,
    required this.onUsePassword,
  });

  @override
  State<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends State<BiometricLockScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  String? error;
  bool busy = false;

  Future<void> _unlock() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final isSupported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;

      if (!isSupported || !canCheck) {
        setState(() => error = "Biometric not available on this device");
        return;
      }

      final ok = await auth.authenticate(
        localizedReason: "Unlock Adolphus",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (ok) widget.onUnlocked();
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    // auto prompt
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fingerprint, size: 72),
              const SizedBox(height: 12),
              const Text(
                "Unlock to continue",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (error != null) ...[
                Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 10),
              ],
              ElevatedButton(
                onPressed: _unlock,
                child: Text(busy ? "Checking..." : "Unlock"),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: widget.onUsePassword,
                child: const Text("Use password instead"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
