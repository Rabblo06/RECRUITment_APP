import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> offer; // offer with populated placementId
  const BookingDetailsScreen({super.key, required this.offer});

  Map<String, dynamic> get p =>
      (offer["placementId"] ?? {}) as Map<String, dynamic>;

  String _s(dynamic v, {String fallback = "—"}) {
    final t = (v ?? "").toString().trim();
    return t.isEmpty ? fallback : t;
  }

  String _dateNice(dynamic dateValue) {
    final raw = (dateValue ?? "").toString().trim();
    if (raw.isEmpty) return "—";
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat("EEE, d MMM yyyy").format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _hourlyRate() {
    final v = p["hourlyRate"] ?? p["payRate"] ?? p["rate"] ?? p["pay"];
    if (v == null) return "—";
    if (v is num) return "£${v.toStringAsFixed(2)}/hr";
    final s = v.toString().trim();
    if (s.isEmpty) return "—";
    return s.contains("/hr") ? s : "£$s/hr";
  }

  String _money(dynamic v) {
    if (v == null) return "—";
    if (v is num) return "£${v.toStringAsFixed(2)}";
    final s = v.toString().trim();
    if (s.isEmpty) return "—";
    return s.startsWith("£") ? s : "£$s";
  }

  // ✅ read correct address fields from your backend schema
  String _addressBlock() {
    final line = (p["addressLine"] ?? "").toString().trim();
    final city = (p["city"] ?? "").toString().trim();
    final post = (p["postcode"] ?? "").toString().trim();

    final parts = [line, city, post].where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return "—";
    return parts.join("\n");
  }

  BoxDecoration _screenBg() {
    // ✅ same style as your Staff Dashboard
    return const BoxDecoration(
      gradient: RadialGradient(
        center: Alignment.topLeft,
        radius: 1.2,
        colors: [Color(0xFF1E3C2E), Color(0xFF0D241C), Color(0xFF071610)],
        stops: [0.0, 0.55, 1.0],
      ),
    );
  }

  Widget _glass({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(16),
    double radius = 18,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.18),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.60),
                fontSize: 12.5,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _s(offer["status"], fallback: "—").toUpperCase();

    final venue = _s(p["venue"]);
    final role = _s(p["roleTitle"] ?? p["role"], fallback: "Shift");

    final date = _dateNice(p["date"]);
    final start = _s(p["startTime"]);
    final end = _s(p["endTime"]);

    final hourly = _hourlyRate();

    // optional totals (if backend saves them)
    final totalHours = offer["totalHoursWorked"] ?? offer["totalHours"];
    final amount = offer["amountWorked"] ?? offer["amount"];

    final notes = _s(p["notes"]); // ✅ correct field
    final address = _addressBlock();

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          "Booking details",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        decoration: _screenBg(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              children: [
                // Top summary
                _glass(
                  padding: const EdgeInsets.all(18),
                  radius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.toLowerCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        venue.toLowerCase(),
                        style: TextStyle(color: Colors.white.withOpacity(0.85)),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Shift
                _glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Shift",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _row("Date", date),
                      _row("Time", "$start - $end"),
                      _row("Rate", hourly),
                      if (totalHours != null) _row("Hours", _s(totalHours)),
                      if (amount != null) _row("Amount", _money(amount)),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Location
                _glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Location",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _row("Venue", venue),
                      _row("Address", address),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Note
                _glass(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Note",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        notes,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
