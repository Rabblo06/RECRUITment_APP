import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class BiometricSetupScreen extends StatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  State<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends State<BiometricSetupScreen> {
  final auth = LocalAuthentication();
  String label = "biometric";
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _detectLabel();
  }

  Future<void> _detectLabel() async {
    try {
      final types = await auth.getAvailableBiometrics();
      if (!mounted) return;

      if (types.contains(BiometricType.face)) {
        setState(() => label = "Face ID");
      } else if (types.contains(BiometricType.fingerprint)) {
        setState(() => label = "Fingerprint");
      } else {
        setState(() => label = "Biometrics");
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _enable() async {
    setState(() {
      busy = true;
      error = null;
    });

    try {
      final supported = await auth.isDeviceSupported();
      final canCheck = await auth.canCheckBiometrics;

      if (!supported || !canCheck) {
        setState(() => error = "Biometric not available on this device");
        return;
      }

      final ok = await auth.authenticate(
        localizedReason: "Confirm $label to enable biometric login",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (!mounted) return;

      if (ok) {
        Navigator.pop(context, true); // enabled
      }
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fingerprint,
                  size: 72,
                  color: Color(0xFF2A2D33),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Biometric authentication is now available",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  "Log in using your phone's $label credentials.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF5A5F66)),
                ),
                const SizedBox(height: 22),

                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: busy ? null : _enable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1F24),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: Text(
                      busy ? "Checking..." : "Enable biometric login",
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false), // skip
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text("Skip for now"),
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
