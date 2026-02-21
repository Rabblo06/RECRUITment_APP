import 'package:flutter/material.dart';
import 'offer_list_screen.dart';

class WaitingScreen extends StatelessWidget {
  final String token;
  const WaitingScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return OfferListScreen(
      token: token,
      title: "Waiting List",
      status: "user_accepted",
      allowActions: false,
    );
  }
}
