import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationsService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  // ✅ Your backend URL
  static const String baseUrl =
      "https://recruitment-apk-3b409a7f0460.herokuapp.com";

  // ✅ MUST match backend channelId you send
  static const String channelId = "recruitment_channel";

  static bool _localReady = false;
  static bool _inited = false;

  // Ensure plugin + channel are initialized (safe to call many times)
  static Future<void> _ensureLocalReady() async {
    if (_localReady) return;

    // Init timezone (needed for scheduled notifications)
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _local.initialize(initSettings);

    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        'Recruitment',
        description: 'Recruitment notifications',
        importance: Importance.max,
      ),
    );

    _localReady = true;
  }

  // Show a local notification immediately (works from background handler too)
  static Future<void> showLocalNow({
    required String title,
    required String body,
  }) async {
    await _ensureLocalReady();

    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Recruitment',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
    );
  }

  // Initialize notifications (call after login when you have JWT)
  static Future<void> init({required String jwtToken}) async {
    if (_inited) return;
    _inited = true;

    // Ask permission (Android 13+ and iOS)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Ensure channel + local plugin exist
    await _ensureLocalReady();

    // Android 13 runtime permission for local notifications
    final androidPlugin = _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (Platform.isAndroid) {
      await androidPlugin?.requestNotificationsPermission();
    }

    // Foreground push notifications: show as local banner
    FirebaseMessaging.onMessage.listen((RemoteMessage msg) async {
      final notif = msg.notification;
      if (notif == null) return;

      await showLocalNow(
        title: notif.title ?? "Adolphus",
        body: notif.body ?? "",
      );
    });

    // Send token to backend
    final fcmToken = await _fcm.getToken();
    if (fcmToken != null) {
      await _sendTokenToBackend(jwtToken, fcmToken);
    }

    // Token refresh -> update backend
    _fcm.onTokenRefresh.listen((newToken) async {
      await _sendTokenToBackend(jwtToken, newToken);
    });
  }

  static Future<void> _sendTokenToBackend(
    String jwtToken,
    String fcmToken,
  ) async {
    try {
      await http.post(
        Uri.parse("$baseUrl/device-token"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $jwtToken",
        },
        body: jsonEncode({"fcmToken": fcmToken}),
      );
    } catch (_) {
      // ignore network errors
    }
  }

  // Schedule 24h + 4h reminders before shift start
  static Future<void> scheduleShiftReminders({
    required String offerId,
    required DateTime shiftStart,
    required String venue,
  }) async {
    await _ensureLocalReady();

    final baseId = offerId.hashCode & 0x7fffffff;

    Future<void> scheduleAt(
      int id,
      DateTime when,
      String title,
      String body,
    ) async {
      if (when.isBefore(DateTime.now())) return;

      await _local.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(when, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Recruitment',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 24 hours before
    await scheduleAt(
      baseId + 24,
      shiftStart.subtract(const Duration(hours: 24)),
      "Shift reminder",
      "Your shift at $venue is tomorrow. Don’t forget to Clock In.",
    );

    // 4 hours before
    await scheduleAt(
      baseId + 4,
      shiftStart.subtract(const Duration(hours: 4)),
      "Your shift is about to begin!",
      "Don’t forget to Clock In.",
    );
  }

  // Cancel reminders (if offer cancelled)
  static Future<void> cancelShiftReminders(String offerId) async {
    await _ensureLocalReady();

    final baseId = offerId.hashCode & 0x7fffffff;
    await _local.cancel(baseId + 24);
    await _local.cancel(baseId + 4);
  }
}
