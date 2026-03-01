import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'services/notifications_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  final title =
      message.notification?.title ?? message.data['title'] ?? 'Adolphus';

  final body =
      message.notification?.body ?? message.data['body'] ?? 'New update';

  await NotificationsService.showLocalNow(title: title, body: body);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // ✅ Register background handler (THIS is the missing part)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Optional: request permission (good for iOS + Android 13+)
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  runApp(const App());
}
