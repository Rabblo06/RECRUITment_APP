import 'dart:ui';
import 'package:flutter/material.dart';

import '../services/api.dart';
import 'booking_details_screen.dart';
import 'new_offers_screen.dart';
import 'booked_screen.dart';
import 'waiting_screen.dart';
import 'login_screen.dart';

class OfferListScreen extends StatefulWidget {
  final String token;
  final String title;
  final String status; // offered / user_accepted / booking_confirmed
  final bool allowActions;

  final String staffName;
  final String staffId;

  const OfferListScreen({
    super.key,
    required this.token,
    required this.staffName,
    required this.staffId,
    required this.title,
    required this.status,
    this.allowActions = false,
  });

  @override
  State<OfferListScreen> createState() => _OfferListScreenState();
}

class _OfferListScreenState extends State<OfferListScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

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
      key: _scaffoldKey,
      drawer: _AppDrawer(
        token: widget.token,
        staffName: widget.staffName,
        onOpenPersonalDetails: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const _PlaceholderScreen(title: "Personal Details"),
            ),
          );
        },
        onOpenOffers: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => NewOffersScreen(
                token: widget.token,
                staffName: widget.staffName,
                staffId: widget.staffId,
              ),
            ),
          );
        },
        onOpenBookings: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => BookedScreen(
                token: widget.token,
                staffName: widget.staffName,
                staffId: widget.staffId,
              ),
            ),
          );
        },
        onOpenPastBookings: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _PlaceholderScreen(title: "Past Bookings"),
            ),
          );
        },
        onOpenPayslips: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _PlaceholderScreen(title: "Payslips"),
            ),
          );
        },
        onOpenLeadConsultant: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const _PlaceholderScreen(title: "Lead Consultant"),
            ),
          );
        },
        onOpenNotifications: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const _PlaceholderScreen(title: "Notifications"),
            ),
          );
        },
        onLogout: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
      ),
      body: Stack(
        children: [
          const _GreenBackground(),
          SafeArea(
            child: Column(
              children: [
                _TopBar(
                  title: widget.title,
                  onRefresh: _load,
                  onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                ),
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

/* ---------- TOP BAR ---------- */

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onRefresh;
  final VoidCallback onMenu;

  const _TopBar({
    required this.title,
    required this.onRefresh,
    required this.onMenu,
  });

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
          IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
        ],
      ),
    );
  }
}

/* ---------- Drawer (same style) ---------- */

class _AppDrawer extends StatelessWidget {
  final String token;
  final String staffName;

  final VoidCallback onOpenPersonalDetails;
  final VoidCallback onOpenOffers;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenPastBookings;
  final VoidCallback onOpenPayslips;
  final VoidCallback onOpenLeadConsultant;
  final VoidCallback onOpenNotifications;
  final VoidCallback onLogout;

  const _AppDrawer({
    required this.token,
    required this.staffName,
    required this.onOpenPersonalDetails,
    required this.onOpenOffers,
    required this.onOpenBookings,
    required this.onOpenPastBookings,
    required this.onOpenPayslips,
    required this.onOpenLeadConsultant,
    required this.onOpenNotifications,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFFE8F0EC);
    const iconColor = Color(0xFFD5E2DB);

    void go(VoidCallback fn) {
      Navigator.pop(context);
      fn();
    }

    return Drawer(
      backgroundColor: const Color(0xFF0B1712),
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF10261D), Color(0xFF08130F)],
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => go(() {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const _PlaceholderScreen(title: "Settings"),
                          ),
                        );
                      }),
                      icon: const Icon(Icons.settings, color: iconColor),
                    ),
                    const Spacer(),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF0E2119),
                        border: Border.all(color: const Color(0xFF2A4A3B)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        "A",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => go(onOpenNotifications),
                      icon: const Icon(
                        Icons.notifications_none,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF2A4A3B), height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    staffName.isEmpty ? "Hi" : "Hi $staffName",
                    style: const TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    _DrawerTile(
                      icon: Icons.person_outline,
                      title: "Personal Details",
                      onTap: () => go(onOpenPersonalDetails),
                    ),
                    _DrawerTile(
                      icon: Icons.calendar_today_outlined,
                      title: "Offers",
                      onTap: () => go(onOpenOffers),
                    ),
                    _DrawerTile(
                      icon: Icons.work_outline,
                      title: "Bookings",
                      onTap: () => go(onOpenBookings),
                    ),
                    _DrawerTile(
                      icon: Icons.history,
                      title: "Past Bookings",
                      onTap: () => go(onOpenPastBookings),
                    ),
                    _DrawerTile(
                      icon: Icons.currency_pound,
                      title: "Payslips",
                      onTap: () => go(onOpenPayslips),
                    ),
                    _DrawerTile(
                      icon: Icons.support_agent_outlined,
                      title: "Lead Consultant",
                      onTap: () => go(onOpenLeadConsultant),
                    ),
                    _DrawerTile(
                      icon: Icons.notifications_none,
                      title: "Notifications",
                      onTap: () => go(onOpenNotifications),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Color(0xFF2A4A3B), height: 1),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => go(onLogout),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E2119),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A4A3B)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.power_settings_new, color: iconColor),
                          SizedBox(width: 10),
                          Text(
                            "Logout",
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DrawerTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFFE8F0EC);
    const iconColor = Color(0xFFD5E2DB);

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: const TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF86A497)),
      onTap: onTap,
      minLeadingWidth: 22,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  const _PlaceholderScreen({required this.title});

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

/* ---------- Background + Glass ---------- */

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
