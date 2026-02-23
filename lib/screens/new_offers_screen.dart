import 'package:flutter/material.dart';
import 'offer_list_screen.dart';

class NewOffersScreen extends StatelessWidget {
  final String token;
  final String staffName;
  final String staffId;

  const NewOffersScreen({
    super.key,
    required this.token,
    required this.staffName,
    required this.staffId,
  });

  @override
  Widget build(BuildContext context) {
    return OfferListScreen(
      token: token,
      staffName: staffName,
      staffId: staffId,
      title: "Offers",
      status: "offered",
      allowActions: true,
    );
  }
}
