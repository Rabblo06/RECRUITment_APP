import 'package:flutter/material.dart';
import 'offer_list_screen.dart';

class BookedScreen extends StatelessWidget {
  final String token;
  const BookedScreen({super.key, required this.token});

  @override
  Widget build(BuildContext context) {
    return OfferListScreen(
      token: token,
      title: "Booked",
      status: "booking_confirmed",
      allowActions: false,
    );
  }
}
