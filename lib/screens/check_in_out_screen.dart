import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

enum ShiftUiState { tooEarly, readyToCheckIn, checkedIn, completed }

class CheckInOutScreen extends StatefulWidget {
  final String token;
  final String staffName;
  final String staffId;

  final Map<String, dynamic> offer;
  final DateTime shiftStart;
  final DateTime shiftEnd;

  const CheckInOutScreen({
    super.key,
    required this.token,
    required this.staffName,
    required this.staffId,
    required this.offer,
    required this.shiftStart,
    required this.shiftEnd,
  });

  @override
  State<CheckInOutScreen> createState() => _CheckInOutScreenState();
}

class _CheckInOutScreenState extends State<CheckInOutScreen> {
  bool loading = false;

  DateTime? checkInTapTime; // for UI/audit
  DateTime? checkOutTime;

  Timer? _ticker;

  String get offerId => (widget.offer["_id"] ?? "").toString();
  String get _prefsKeyTap => "checkin_tap_$offerId";

  Map<String, dynamic> get placement =>
      (widget.offer["placementId"] ?? {}) as Map<String, dynamic>;

  DateTime get _opensAt =>
      widget.shiftStart.subtract(const Duration(minutes: 10));

  // UI colors (matches your app)
  final Color _btnColor = const Color(0xFF18322B);

  @override
  void initState() {
    super.initState();
    _loadStoredCheckInTap();
    _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _loadStoredCheckInTap() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefsKeyTap);
    if (s != null) {
      setState(() => checkInTapTime = DateTime.tryParse(s));
    }
  }

  Future<void> _storeCheckInTap(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKeyTap, dt.toIso8601String());
  }

  Future<void> _clearCheckInTap() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKeyTap);
  }

  String _fmtTime(DateTime dt) => DateFormat("HH:mm").format(dt);

  String _fmtDuration(Duration d) {
    final totalSeconds = d.inSeconds;
    final h = (totalSeconds ~/ 3600).toString().padLeft(2, "0");
    final m = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, "0");
    final s = (totalSeconds % 60).toString().padLeft(2, "0");
    return "$h:$m:$s";
  }

  // Timer pill text:
  // - before check-in: time until start
  // - after check-in: elapsed from shiftStart (your rule)
  // - after checkout: total worked from shiftStart -> checkout
  String _topTimerText() {
    final now = DateTime.now();

    if (checkOutTime != null) {
      final dur = checkOutTime!.difference(widget.shiftStart);
      return _fmtDuration(dur.isNegative ? Duration.zero : dur);
    }

    if (checkInTapTime != null) {
      final dur = now.difference(widget.shiftStart);
      return _fmtDuration(dur.isNegative ? Duration.zero : dur);
    }

    final untilStart = widget.shiftStart.difference(now);
    return _fmtDuration(untilStart.isNegative ? Duration.zero : untilStart);
  }

  double _getHourlyRate() {
    final v =
        placement["hourlyRate"] ??
        placement["payRate"] ??
        placement["rate"] ??
        placement["pay"] ??
        0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  ShiftUiState get _uiState {
    final now = DateTime.now();

    if (checkInTapTime != null && checkOutTime != null) {
      return ShiftUiState.completed;
    }
    if (checkInTapTime != null) return ShiftUiState.checkedIn;

    if (now.isBefore(_opensAt)) return ShiftUiState.tooEarly;
    return ShiftUiState.readyToCheckIn;
  }

  // ---------- Popups ----------

  void _showTooEarlyPopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF153029),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              const Text(
                "Your shift hasn’t started yet",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                "You can check-in in 10 minutes",
                style: TextStyle(color: Colors.white.withOpacity(0.75)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _btnColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Got it"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEarlyCheckoutConfirm() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Shift not ended yet"),
        content: const Text(
          "Your shift is not done yet.\nAre you sure you want to clock-out?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Clock out"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await _sendCheckOut();
    }
  }

  // ---------- Actions ----------

  Future<void> _sendCheckIn() async {
    final now = DateTime.now();
    if (now.isBefore(_opensAt)) {
      _showTooEarlyPopup();
      return;
    }
    if (now.isAfter(widget.shiftEnd)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Shift already ended.")));
      }
      return;
    }

    setState(() => loading = true);
    try {
      final tap = DateTime.now();

      await Api.post(
        "/telegram/check",
        token: widget.token,
        body: {
          "type": "checkin",
          "staffId": widget.staffId,
          "staffName": widget.staffName,
          "offerId": offerId,
        },
      );

      await _storeCheckInTap(tap);
      setState(() => checkInTapTime = tap);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Check-in sent ✅")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Check-in failed: $e")));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sendCheckOut() async {
    if (checkInTapTime == null) return;

    setState(() => loading = true);
    try {
      final now = DateTime.now();

      // ✅ your rule: calculate from scheduled shiftStart
      final dur = now.difference(widget.shiftStart);
      final safeMinutes = dur.inMinutes < 0 ? 0 : dur.inMinutes;
      final totalHours = safeMinutes / 60.0;

      final hourlyRate = _getHourlyRate();
      final amount = totalHours * hourlyRate;

      final venue = (placement["venueName"] ?? placement["venue"] ?? "")
          .toString();
      final role = (placement["roleTitle"] ?? placement["role"] ?? "")
          .toString();
      final dateStr = (placement["date"] ?? "").toString();
      final startTime = (placement["startTime"] ?? "").toString();
      final endTime = (placement["endTime"] ?? "").toString();

      // Telegram summary (keep)
      await Api.post(
        "/telegram/check",
        token: widget.token,
        body: {
          "type": "checkout",
          "staffId": widget.staffId,
          "staffName": widget.staffName,
          "offerId": offerId,
          "venue": venue,
          "role": role,
          "date": dateStr,
          "startTime": startTime,
          "endTime": endTime,
          "checkIn": _fmtTime(checkInTapTime!),
          "checkOut": _fmtTime(now),
          "totalHours": double.parse(totalHours.toStringAsFixed(2)),
          "amount": double.parse(amount.toStringAsFixed(2)),
        },
      );

      // ✅ Mark offer completed in backend (so it disappears)
      await Api.post(
        "/offers/$offerId/checkout",
        token: widget.token,
        body: {},
      );

      await _clearCheckInTap();
      setState(() => checkOutTime = now);

      if (mounted) {
        Navigator.pop(context, true); // ✅ refresh dashboard/list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Check-out failed: $e")));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------- UI ----------

  BoxDecoration _screenBg() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0D1F1A), Color(0xFF0B1A16)],
      ),
    );
  }

  Widget _timerPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        _topTimerText(),
        style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _shiftCard() {
    final venue = (placement["venueName"] ?? placement["venue"] ?? "Venue")
        .toString();
    final role = (placement["roleTitle"] ?? placement["role"] ?? "Role")
        .toString();

    final date = DateFormat('d MMM yyyy').format(widget.shiftStart);
    final start = DateFormat('hh:mm a').format(widget.shiftStart);
    final end = DateFormat('hh:mm a').format(widget.shiftEnd);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            role.toLowerCase(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(date, style: TextStyle(color: Colors.white.withOpacity(0.70))),
          const SizedBox(height: 4),
          Text(
            "$start - $end",
            style: TextStyle(color: Colors.white.withOpacity(0.70)),
          ),
          const SizedBox(height: 10),
          Text(
            venue.toLowerCase(),
            style: TextStyle(color: Colors.white.withOpacity(0.85)),
          ),
        ],
      ),
    );
  }

  Widget _timelineCard() {
    if (checkInTapTime == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                _fmtTime(checkInTapTime!),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.circle, size: 8, color: Colors.white.withOpacity(0.9)),
              const SizedBox(width: 10),
              Text(
                "Check in",
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
              ),
            ],
          ),
          if (checkOutTime != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  _fmtTime(checkOutTime!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.circle,
                  size: 8,
                  color: Colors.white.withOpacity(0.9),
                ),
                const SizedBox(width: 10),
                Text(
                  "Check out",
                  style: TextStyle(color: Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton() {
    final state = _uiState;

    String label;
    VoidCallback? onPressed;

    if (loading) {
      label = "Please wait...";
      onPressed = null;
    } else {
      switch (state) {
        case ShiftUiState.tooEarly:
          label = "Check in";
          onPressed = _showTooEarlyPopup;
          break;

        case ShiftUiState.readyToCheckIn:
          label = "Check in";
          onPressed = _sendCheckIn;
          break;

        case ShiftUiState.checkedIn:
          label = "Check out";
          onPressed = () {
            final now = DateTime.now();
            if (now.isBefore(widget.shiftEnd)) {
              _showEarlyCheckoutConfirm();
            } else {
              _sendCheckOut();
            }
          };
          break;

        case ShiftUiState.completed:
          label = "Completed";
          onPressed = null;
          break;
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 58,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _btnColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(label, style: const TextStyle(fontSize: 15)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateTitle = DateFormat("EEEE, MMM d").format(widget.shiftStart);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(dateTitle, style: const TextStyle(color: Colors.white)),
      ),
      body: Container(
        decoration: _screenBg(),
        width: double.infinity,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              children: [
                const SizedBox(height: 8),
                _timerPill(),
                const SizedBox(height: 18),
                if (_uiState == ShiftUiState.checkedIn ||
                    _uiState == ShiftUiState.completed) ...[
                  _timelineCard(),
                  const SizedBox(height: 14),
                ],
                _shiftCard(),
                const Spacer(),
                _actionButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
