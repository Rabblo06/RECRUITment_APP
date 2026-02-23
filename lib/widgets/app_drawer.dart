import 'package:flutter/material.dart';

import '../services/session.dart';
import '../screens/login_screen.dart';
import '../screens/new_offers_screen.dart';
import '../screens/booked_screen.dart';
import '../screens/past_bookings_screen.dart';
import '../screens/simple_placeholder_screen.dart';

class AppDrawer extends StatelessWidget {
  final String token;
  final String staffName;
  final String staffId;

  const AppDrawer({
    super.key,
    required this.token,
    required this.staffName,
    required this.staffId,
  });

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context); // close drawer
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _logout(BuildContext context) async {
    await Session.saveLogin(token: "", name: "", role: "", staffId: "");
    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    const textColor = Color(0xFFE8F0EC);
    const subTextColor = Color(0xFFB8C6BE);
    const iconColor = Color(0xFFD5E2DB);

    return Drawer(
      backgroundColor: const Color(0xFF0B1712), // dark green base
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
              // Top row (settings - logo - bell)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _go(
                        context,
                        const SimplePlaceholderScreen(title: "Settings"),
                      ),
                      icon: const Icon(Icons.settings, color: iconColor),
                    ),
                    const Spacer(),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFF0E2119),
                        border: Border.all(
                          color: const Color(0xFF2A4A3B),
                          width: 1,
                        ),
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
                      onPressed: () => _go(
                        context,
                        const SimplePlaceholderScreen(title: "Notifications"),
                      ),
                      icon: const Icon(
                        Icons.notifications_none,
                        color: iconColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
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

              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2A4A3B), height: 1),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  children: [
                    _tile(
                      icon: Icons.person_outline,
                      title: "Personal Details",
                      onTap: () => _go(
                        context,
                        const SimplePlaceholderScreen(
                          title: "Personal Details",
                        ),
                      ),
                      iconColor: iconColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    _tile(
                      icon: Icons.calendar_today_outlined,
                      title: "Offers",
                      onTap: () => _go(
                        context,
                        NewOffersScreen(
                          token: token,
                          staffName: staffName,
                          staffId: staffId,
                        ),
                      ),
                      iconColor: iconColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    _tile(
                      icon: Icons.work_outline,
                      title: "Bookings",
                      onTap: () => _go(
                        context,
                        BookedScreen(
                          token: token,
                          staffName: staffName,
                          staffId: staffId,
                        ),
                      ),
                      iconColor: iconColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    _tile(
                      icon: Icons.history,
                      title: "Past Bookings",
                      onTap: () => _go(
                        context,
                        PastBookingsScreen(
                          token: token,
                          staffName: staffName,
                          staffId: staffId,
                        ),
                      ),
                      iconColor: iconColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    _tile(
                      icon: Icons.currency_pound,
                      title: "Payslips",
                      onTap: () => _go(
                        context,
                        const SimplePlaceholderScreen(title: "Payslips"),
                      ),
                      iconColor: iconColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    _tile(
                      icon: Icons.support_agent_outlined,
                      title: "Lead Consultant",
                      onTap: () => _go(
                        context,
                        const SimplePlaceholderScreen(title: "Lead Consultant"),
                      ),
                      iconColor: iconColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    _tile(
                      icon: Icons.notifications_none,
                      title: "Notifications",
                      onTap: () => _go(
                        context,
                        const SimplePlaceholderScreen(title: "Notifications"),
                      ),
                      iconColor: iconColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    const SizedBox(height: 14),
                    const Divider(color: Color(0xFF2A4A3B), height: 1),
                  ],
                ),
              ),

              // Logout bottom-left
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _logout(context),
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

  Widget _tile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required Color iconColor,
    required Color textColor,
    required Color subTextColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right, color: Color(0xFF86A497)),
      onTap: onTap,
      minLeadingWidth: 22,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      splashColor: const Color(0xFF1A3A2D),
      hoverColor: const Color(0xFF1A3A2D),
    );
  }
}
