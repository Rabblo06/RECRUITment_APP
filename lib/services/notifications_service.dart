import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

class NotificationsService {
  static final _fcm = FirebaseMessaging.instance;
  static final _local = FlutterLocalNotificationsPlugin();

  // CHANGE to your backend URL
  static const String baseUrl = "http://192.168.1.212:4000";

  static Future<void> init({required String jwtToken}) async {
    // Android 13+ runtime permission (safe to call always)
    await _fcm.requestPermission();

    // Local notifications init (for foreground messages)
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _local.initialize(initSettings);

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    print("🔔 Permission: ${settings.authorizationStatus}");

    final token = await FirebaseMessaging.instance.getToken();
    print("✅ FCM TOKEN: $token");
    // Get FCM token
    final fcmToken = await _fcm.getToken();
    if (fcmToken != null) {
      await _sendTokenToBackend(jwtToken: jwtToken, fcmToken: fcmToken);
    }

    // If token refreshes
    _fcm.onTokenRefresh.listen((newToken) async {
      await _sendTokenToBackend(jwtToken: jwtToken, fcmToken: newToken);
    });

    // Foreground message → show local notification
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final title = msg.notification?.title ?? "New notification";
      final body = msg.notification?.body ?? "";

      const androidDetails = AndroidNotificationDetails(
        'recruitment_channel',
        'Recruitment',
        importance: Importance.max,
        priority: Priority.high,
      );

      await _local.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );
    });
  }

  static Future<void> _sendTokenToBackend({
    required String jwtToken,
    required String fcmToken,
  }) async {
    final res = await http.post(
      Uri.parse("$baseUrl/device-token"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $jwtToken",
      },
      body: jsonEncode({"fcmToken": fcmToken}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      // Don’t crash app, just ignore for now
    }
  }
}
