import 'package:flutter/material.dart';
import '../services/api.dart';

class NewOffersScreen extends StatefulWidget {
  final String token;
  const NewOffersScreen({super.key, required this.token});

  @override
  State<NewOffersScreen> createState() => _NewOffersScreenState();
}

class _NewOffersScreenState extends State<NewOffersScreen> {
  bool loading = true;
  String? error;
  List<dynamic> offers = [];

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
        "/offers/my?status=offered",
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      appBar: AppBar(
        title: const Text("New Offers"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  if (offers.isEmpty && error == null)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: Text("No new offers")),
                    ),
                  ...offers.map((offer) {
                    final p = offer["placementId"] ?? {};
                    final offerId = offer["_id"].toString();

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (p["venue"] ?? "").toString(),
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (p["roleTitle"] ?? "").toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text((p["date"] ?? "").toString()),
                          const SizedBox(height: 6),
                          Text(
                            "${p["startTime"] ?? ""} - ${p["endTime"] ?? ""}",
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _respond(offerId, "accept"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF16E63F),
                                    foregroundColor: Colors.black,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text("Accept"),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _respond(offerId, "reject"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF2A2A),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: const Text("Reject"),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
    );
  }
}
