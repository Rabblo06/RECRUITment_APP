import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFF0D241C);

    return MaterialApp(
      title: 'Recruitment App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: bg,
      ),
      home: const SplashScreen(),
    );
  }
}
