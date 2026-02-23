import 'package:flutter/material.dart';

class SimplePlaceholderScreen extends StatelessWidget {
  final String title;
  const SimplePlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          "$title (Coming soon)",
          style: const TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}
