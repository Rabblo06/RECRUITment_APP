import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart'; // your real root widget file
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  final fcmToken = await FirebaseMessaging.instance.getToken();
  print("🔔 FCM permission: ${settings.authorizationStatus}");
  print("✅ FCM TOKEN: $fcmToken");
  runApp(const App()); // your real root widget
}
