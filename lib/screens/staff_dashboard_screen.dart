import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api.dart';
import 'booked_screen.dart';
import 'new_offers_screen.dart';
import 'waiting_screen.dart';
import 'booking_details_screen.dart';

class StaffDashboardScreen extends StatefulWidget {
  final String token;
  final String staffName;

  const StaffDashboardScreen({
    super.key,
    required this.token,
    required this.staffName,
  });

  @override
  State createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  bool loading = true;
  String? error;

  List bookingConfirmed = [];
  int countOffered = 0;
  int countWaiting = 0;
  int countConfirmed = 0;

  int navIndex = 0;

  // -------- Timer state --------
  Timer? _ticker;
  String timerText = "00:00:00";

  Map<String, dynamic>? nextShiftOffer;
  DateTime? nextShiftStart;
  DateTime? nextShiftEnd;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
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

      _setNextShiftFromConfirmed();
      _updateTimerText();
    } catch (e) {
      setState(() => error = e.toString().replaceAll("Exception: ", ""));
    } finally {
      setState(() => loading = false);
    }
  }

  // ------------------ Timer logic ------------------

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimerText();
    });
  }

  void _setNextShiftFromConfirmed() {
    DateTime? bestStart;
    DateTime? bestEnd;
    Map<String, dynamic>? bestOffer;

    final now = DateTime.now();

    for (final offer in bookingConfirmed) {
      final p = offer["placementId"] ?? {};
      final dateStr = (p["date"] ?? "").toString();
      final startStr = (p["startTime"] ?? "").toString();
      final endStr = (p["endTime"] ?? "").toString();

      final start = _combineDateAndTime(dateStr, startStr);
      final end = _combineDateAndTime(dateStr, endStr);

      if (start == null || end == null) continue;

      // ignore already finished shifts
      if (end.isBefore(now)) continue;

      // choose the soonest upcoming (or current running)
      final candidateKey = start.isAfter(now) ? start : now;

      if (bestStart == null) {
        bestStart = start;
        bestEnd = end;
        bestOffer = offer;
      } else {
        final bestKey = bestStart!.isAfter(now) ? bestStart! : now;
        if (candidateKey.isBefore(bestKey)) {
          bestStart = start;
          bestEnd = end;
          bestOffer = offer;
        }
      }
    }

    nextShiftStart = bestStart;
    nextShiftEnd = bestEnd;
    nextShiftOffer = bestOffer;
  }

  DateTime? _combineDateAndTime(String dateStr, String timeStr) {
    DateTime date;
    try {
      date = DateTime.parse(dateStr).toLocal();
    } catch (_) {
      return null;
    }

    final hm = _parseTimeToHourMinute(timeStr);
    if (hm == null) return null;

    return DateTime(date.year, date.month, date.day, hm.$1, hm.$2);
    // NOTE: endTime is assumed same day; if your shifts pass midnight tell me.
  }

  (int, int)? _parseTimeToHourMinute(String timeStr) {
    final s = timeStr.trim();

    // "HH:mm"
    final hm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
    if (hm != null) {
      return (int.parse(hm.group(1)!), int.parse(hm.group(2)!));
    }

    // "h:mm AM/PM" or "h AM/PM"
    try {
      final dt = DateFormat.jm().parse(s);
      return (dt.hour, dt.minute);
    } catch (_) {}

    try {
      final dt = DateFormat("h:mm a").parse(s);
      return (dt.hour, dt.minute);
    } catch (_) {}

    return null;
  }

  void _updateTimerText() {
    final now = DateTime.now();

    // Try to select next shift if missing
    if (nextShiftStart == null) {
      if (bookingConfirmed.isNotEmpty) {
        _setNextShiftFromConfirmed();
      }
      if (nextShiftStart == null) {
        if (mounted && timerText != "00:00:00") {
          setState(() => timerText = "00:00:00");
        }
        return;
      }
    }

    // If shift finished, select the next one
    final end = nextShiftEnd;
    if (end != null && end.isBefore(now)) {
      _setNextShiftFromConfirmed();
      if (nextShiftStart == null) {
        if (mounted) setState(() => timerText = "00:00:00");
        return;
      }
    }

    final start = nextShiftStart!;
    final diff = start.difference(now);

    // ✅ ALWAYS show HH:MM:SS
    if (diff.inSeconds > 0) {
      // countdown to shift
      final txt = _formatHms(diff);
      if (mounted && timerText != txt) setState(() => timerText = txt);
      return;
    }

    // elapsed since shift start
    final elapsed = now.difference(start);
    final txt = _formatHms(elapsed);
    if (mounted && timerText != txt) setState(() => timerText = txt);
  }

  String _formatHms(Duration d) {
    final total = d.inSeconds.abs();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  // ------------------ Date formatting for placement cards ------------------

  static String _formatWeekday(String dateStr) {
    final dt = _parseDate(dateStr);
    return DateFormat('EEEE').format(dt);
  }

  static String _formatDateNice(String dateStr) {
    final dt = _parseDate(dateStr);
    return DateFormat('d MMM yyyy').format(dt);
  }

  static DateTime _parseDate(String dateStr) {
    try {
      return DateTime.parse(dateStr).toLocal();
    } catch (_) {
      return DateTime.now();
    }
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        children: [
          const _GreenBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(
                    name: widget.staffName,
                    onMenu: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Menu tapped")),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  const _SectionTitle(title: "Placements"),
                  const SizedBox(height: 10),

                  SizedBox(
                    height: 112,
                    child: bookingConfirmed.isEmpty
                        ? const _EmptyGlass(text: "No upcoming placements")
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: bookingConfirmed.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 12),
                            itemBuilder: (context, i) {
                              final offer = bookingConfirmed[i];
                              final p = offer["placementId"] ?? {};
                              final dateStr = (p["date"] ?? "").toString();

                              final weekday = _formatWeekday(dateStr);
                              final dateNice = _formatDateNice(dateStr);

                              return _GlassPlacementCard(
                                role: (p["roleTitle"] ?? "Role").toString(),
                                day: "$weekday • $dateNice",
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

                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookedScreen(token: widget.token),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFE0C482),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      child: const Text("View All  >"),
                    ),
                  ),

                  const SizedBox(height: 14),
                  const _SectionTitle(title: "Summary"),
                  const SizedBox(height: 10),

                  _SummaryGridSameSize(
                    newOfferCount: countOffered,
                    waitingCount: countWaiting,
                    bookedCount: countConfirmed,
                    timerText: timerText,
                    onTapNewOffer: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NewOffersScreen(token: widget.token),
                        ),
                      ).then((_) => _loadDashboard());
                    },
                    onTapWaiting: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WaitingScreen(token: widget.token),
                        ),
                      );
                    },
                    onTapBooked: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookedScreen(token: widget.token),
                        ),
                      );
                    },
                    onTapCheck: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Check in/out screen next ✅"),
                        ),
                      );
                    },
                  ),

                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(left: 18, right: 18, bottom: 14),
                child: _BottomGlassNav(
                  index: navIndex,
                  onChanged: (i) => setState(() => navIndex = i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Background ---------------- */

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

/* ---------------- Header ---------------- */

class _Header extends StatelessWidget {
  final String name;
  final VoidCallback onMenu;

  const _Header({required this.name, required this.onMenu});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Hi $name",
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                "Welcome",
                style: TextStyle(fontSize: 16, color: Color(0xFFD8E6DF)),
              ),
            ],
          ),
        ),
        IconButton(onPressed: onMenu, icon: const Icon(Icons.menu_rounded)),
      ],
    );
  }
}

/* ---------------- Titles ---------------- */

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }
}

/* ---------------- Placements ---------------- */

class _EmptyGlass extends StatelessWidget {
  final String text;
  const _EmptyGlass({required this.text});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Center(
        child: Text(text, style: const TextStyle(color: Color(0xFFD8E6DF))),
      ),
    );
  }
}

class _GlassPlacementCard extends StatelessWidget {
  final String role;
  final String day;
  final String time;
  final VoidCallback onTap;

  const _GlassPlacementCard({
    required this.role,
    required this.day,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 220,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                day,
                style: const TextStyle(fontSize: 12, color: Color(0xFFD8E6DF)),
              ),
              const SizedBox(height: 6),
              Text(
                time,
                style: const TextStyle(fontSize: 12, color: Color(0xFFD8E6DF)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- Summary ---------------- */

class _SummaryGridSameSize extends StatelessWidget {
  final int newOfferCount;
  final int waitingCount;
  final int bookedCount;
  final String timerText;

  final VoidCallback onTapNewOffer;
  final VoidCallback onTapWaiting;
  final VoidCallback onTapBooked;
  final VoidCallback onTapCheck;

  const _SummaryGridSameSize({
    required this.newOfferCount,
    required this.waitingCount,
    required this.bookedCount,
    required this.timerText,
    required this.onTapNewOffer,
    required this.onTapWaiting,
    required this.onTapBooked,
    required this.onTapCheck,
  });

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 22,
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        height: 210,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      title: "New Offer",
                      value: "$newOfferCount",
                      onTap: onTapNewOffer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      title: "Booked",
                      value: "$bookedCount",
                      onTap: onTapBooked,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      title: "Waiting",
                      value: "$waitingCount",
                      onTap: onTapWaiting,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      title: "Check in/out",
                      value: timerText,
                      onTap: onTapCheck,
                      valueColor: const Color(0xFFB8892E),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String title;
  final String value;
  final VoidCallback onTap;
  final Color? valueColor;

  const _SummaryTile({
    required this.title,
    required this.value,
    required this.onTap,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 88,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEDE7D6),
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: title == "Check in/out"
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF4B4B4B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: TextStyle(
                        color: valueColor ?? const Color(0xFFB8892E),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF4B4B4B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F2E5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: Color(0xFF4B4B4B),
                          fontWeight: FontWeight.w800,
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

/* ---------------- Pay Slip ---------------- */

/* ---------------- Bottom Nav ---------------- */

class _BottomGlassNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _BottomGlassNav({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _Glass(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavIcon(
            icon: Icons.home_rounded,
            selected: index == 0,
            onTap: () => onChanged(0),
          ),
          _NavIcon(
            icon: Icons.calendar_month_rounded,
            selected: index == 1,
            onTap: () => onChanged(1),
          ),
          _NavIcon(
            icon: Icons.history_rounded,
            selected: index == 2,
            onTap: () => onChanged(2),
          ),
          _NavIcon(
            icon: Icons.person_rounded,
            selected: index == 3,
            onTap: () => onChanged(3),
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          size: 24,
          color: selected ? const Color(0xFFE6D9A8) : const Color(0xFFB9C7BF),
        ),
      ),
    );
  }
}

/* ---------------- Glass ---------------- */

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
