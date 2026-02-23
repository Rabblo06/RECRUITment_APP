import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _kToken = 'token';
  static const _kName = 'name';
  static const _kRole = 'role';
  static const _kStaffId = 'staff_id';

  static const _kBiometricEnabled = 'biometric_enabled';
  static const _kBiometricPromptShown = 'biometric_prompt_shown'; // ✅ new

  static Future<void> saveLogin({
    required String token,
    required String name,
    required String role,
    required String staffId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kName, name);
    await prefs.setString(_kRole, role);
    await prefs.setString(_kStaffId, staffId);
  }

  static Future<String?> token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kToken);
  }

  static Future<String?> name() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kName);
  }

  static Future<String?> role() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRole);
  }

  static Future<String?> staffId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kStaffId);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<void> setBiometricEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricEnabled, value);
  }

  static Future<bool> biometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricEnabled) ?? false;
  }

  // ✅ Ask only once flag
  static Future<bool> biometricPromptShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricPromptShown) ?? false;
  }

  static Future<void> setBiometricPromptShown(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricPromptShown, value);
  }

  static const _kBiometricPrompted = 'biometric_prompted';

  static Future<void> setBiometricPrompted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kBiometricPrompted, value);
  }

  static Future<bool> biometricPrompted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kBiometricPrompted) ?? false;
  }
}
