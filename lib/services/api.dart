import 'dart:convert';
import 'package:http/http.dart' as http;

class Api {
  // ✅ emulator
  static const String baseUrl =
      "https://recruitment-apk-3b409a7f0460.herokuapp.com";

  static Future<dynamic> get(String path, {required String token}) async {
    final res = await http.get(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    return _handle(res);
  }

  static Future<dynamic> post(
    String path, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  static Future<dynamic> patch(
    String path, {
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final res = await http.patch(
      Uri.parse("$baseUrl$path"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(body),
    );
    return _handle(res);
  }

  static dynamic _handle(http.Response res) {
    final data = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw Exception(data?["message"] ?? "API error ${res.statusCode}");
  }
}
