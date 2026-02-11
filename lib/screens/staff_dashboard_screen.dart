import 'package:flutter/material.dart';
import '../services/api.dart';
import 'booking_details_screen.dart';
import 'new_offers_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  final String token;
  final String staffName;

  const StaffDashboardScreen({
    super.key,
    required this.token,
    required this.staffName,
  });

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  bool loading = true;
  String? error;

  List<dynamic> bookingConfirmed = [];
  int countOffered = 0;
  int countWaiting = 0;
  int countConfirmed = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final offered = await Api.get(
        "/offers/my?status=offered",
        token: widget.token,
      );
      final waiting = await Api.get(
        "/offers/my?status=user_accepted",
        token: widget.token,
      );
      final confirmed = await Api.get(
        "/offers/my?status=booking_confirmed",
        token: widget.token,
      );

      setState(() {
        countOffered = (offered as List).length;
        countWaiting = (waiting as List).length;
        countConfirmed = (confirmed as List).length;
        bookingConfirmed = confirmed;
      });
    } catch (e) {
      setState(() => error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _topHeader(),
              const SizedBox(height: 14),

              _sectionCard(
                icon: Icons.badge_outlined,
                title: "Upcoming Placements",
                child: bookingConfirmed.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: Text("No upcoming placements")),
                      )
                    : SizedBox(
                        height: 92,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: bookingConfirmed.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, i) {
                            final offer = bookingConfirmed[i];
                            final p = offer["placementId"] ?? {};
                            return _upcomingMiniCard(
                              title: (p["roleTitle"] ?? "Role").toString(),
                              date: (p["date"] ?? "").toString(),
                              time:
                                  "${p["startTime"] ?? ""} - ${p["endTime"] ?? ""}",
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BookingDetailsScreen(offer: offer),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
              ),

              const SizedBox(height: 14),

              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              _sectionCard(
                icon: Icons.view_list_outlined,
                title: "Placement Summary",
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _summaryBox(
                            const Color(0xFFE74C3C),
                            countOffered,
                            "New Offer\n(Not Booked)",
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryBox(
                            const Color(0xFFF1B51C),
                            countWaiting,
                            "Waiting List\n(Not Booked)",
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _summaryBox(
                            const Color(0xFF65B80E),
                            countConfirmed,
                            "Booking Confirmed\n(Booked)",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  NewOffersScreen(token: widget.token),
                            ),
                          );
                          _loadDashboard(); // refresh counts after accept/reject
                        },
                        child: const Text("Open New Offers"),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topHeader() {
    return Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: Color(0xFFE6E6E6),
          child: Icon(Icons.person, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            "Hi, ${widget.staffName}",
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(onPressed: _loadDashboard, icon: const Icon(Icons.refresh)),
      ],
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _upcomingMiniCard({
    required String title,
    required String date,
    required String time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE1E1E1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(date, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text(time, maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _summaryBox(Color c, int n, String label) {
    return Column(
      children: [
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(18),
          ),
          alignment: Alignment.center,
          child: Text(
            "$n",
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
