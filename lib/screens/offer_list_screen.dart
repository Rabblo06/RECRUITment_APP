import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/api.dart';
import 'booking_details_screen.dart';

class OfferListScreen extends StatefulWidget {
  final String token;
  final String title;
  final String status; // offered / user_accepted / booking_confirmed
  final bool allowActions;

  const OfferListScreen({
    super.key,
    required this.token,
    required this.title,
    required this.status,
    this.allowActions = false,
  });

  @override
  State<OfferListScreen> createState() => _OfferListScreenState();
}

class _OfferListScreenState extends State<OfferListScreen> {
  bool loading = true;
  String? error;
  List offers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await Api.get(
        "/offers/my?status=${widget.status}",
        token: widget.token,
      );
      setState(() => offers = (data as List));
    } catch (e) {
      setState(() => error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _respond(String offerId, String action) async {
    try {
      await Api.patch(
        "/offers/$offerId/respond",
        token: widget.token,
        body: {"action": action},
      );
      setState(() => offers.removeWhere((o) => o["_id"] == offerId));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Done: $action")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll("Exception: ", ""))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const _GreenBackground(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(title: widget.title, onRefresh: _load),
                Expanded(
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                            children: [
                              if (error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              if (offers.isEmpty && error == null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 60),
                                  child: Center(
                                    child: Text(
                                      "Nothing here",
                                      style: TextStyle(
                                        color: Color(0xFFD8E6DF),
                                      ),
                                    ),
                                  ),
                                ),
                              ...offers.map((offer) {
                                final p = offer["placementId"] ?? {};
                                final offerId = offer["_id"].toString();

                                final venue = (p["venue"] ?? "").toString();
                                final role = (p["roleTitle"] ?? "Role")
                                    .toString();
                                final date = (p["date"] ?? "").toString();
                                final time =
                                    "${p["startTime"] ?? ""} - ${p["endTime"] ?? ""}";
                                final pay =
                                    "£${p["hourlyRate"] ?? ""}/hr · ${p["totalHours"] ?? ""}h";

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _Glass(
                                    radius: 18,
                                    padding: const EdgeInsets.all(14),
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                BookingDetailsScreen(
                                                  offer: offer,
                                                ),
                                          ),
                                        );
                                      },
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            venue,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            role,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: Color(0xFFD8E6DF),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            date,
                                            style: const TextStyle(
                                              color: Color(0xFFD8E6DF),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            time,
                                            style: const TextStyle(
                                              color: Color(0xFFD8E6DF),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            pay,
                                            style: const TextStyle(
                                              color: Color(0xFFE6D9A8),
                                            ),
                                          ),
                                          if (widget.allowActions) ...[
                                            const SizedBox(height: 12),
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: ElevatedButton(
                                                    onPressed: () => _respond(
                                                      offerId,
                                                      "accept",
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                            0xFFEDE7D6,
                                                          ),
                                                      foregroundColor:
                                                          const Color(
                                                            0xFF0D241C,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      "Confirm",
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: OutlinedButton(
                                                    onPressed: () => _respond(
                                                      offerId,
                                                      "reject",
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor:
                                                          const Color(
                                                            0xFFEDE7D6,
                                                          ),
                                                      side: const BorderSide(
                                                        color: Color(
                                                          0x55FFFFFF,
                                                        ),
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              14,
                                                            ),
                                                      ),
                                                    ),
                                                    child: const Text("Reject"),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------- UI bits ---------- */

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onRefresh;

  const _TopBar({required this.title, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          IconButton(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _GreenBackground extends StatelessWidget {
  const _GreenBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.2,
          colors: [Color(0xFF1E3C2E), Color(0xFF0D241C), Color(0xFF071610)],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  const _Glass({
    required this.child,
    this.radius = 18,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: const Color(0x1AFFFFFF),
            border: Border.all(color: const Color(0x22FFFFFF), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
