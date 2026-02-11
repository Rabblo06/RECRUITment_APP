import 'package:flutter/material.dart';

class BookingDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> offer; // offer with populated placementId
  const BookingDetailsScreen({super.key, required this.offer});

  @override
  Widget build(BuildContext context) {
    final p = (offer["placementId"] ?? {}) as Map<String, dynamic>;

    final venue = (p["venue"] ?? "").toString();
    final roleTitle = (p["roleTitle"] ?? "").toString();
    final date = (p["date"] ?? "").toString();
    final start = (p["startTime"] ?? "").toString();
    final end = (p["endTime"] ?? "").toString();

    final rate = (p["hourlyRate"] ?? 0).toString();
    final hours = (p["totalHours"] ?? 0).toString();

    final address =
        "${p["addressLine"] ?? ""}\n${p["city"] ?? ""}\n${p["postcode"] ?? ""}";
    final notes = (p["notes"] ?? "").toString();
    final status = (offer["status"] ?? "").toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      appBar: AppBar(
        title: const Text("Booking"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            title: venue,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.attach_file),
                SizedBox(width: 14),
                Icon(Icons.location_on_outlined),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roleTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(date, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text("$start - $end"),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: "Potential Earnings",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "This figure is before Tax, NI, Pension\nand any breaks are deducted",
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Text(
                  "£$rate x $hours hours",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            title: "Status",
            child: Text(
              status,
              style: const TextStyle(
                color: Color(0xFF65B80E),
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _card(title: "Address", child: Text(address)),
          const SizedBox(height: 12),
          _card(title: "Notes", child: Text(notes)),
        ],
      ),
    );
  }

  Widget _card({
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
