import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';

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
  DateTime? checkInTime;

  String get offerId => (widget.offer["_id"] ?? "").toString();
  String get _prefsKey => "checkin_$offerId";

  Map<String, dynamic> get placement =>
      (widget.offer["placementId"] ?? {}) as Map<String, dynamic>;

  @override
  void initState() {
    super.initState();
    _loadStoredCheckin();
  }

  Future<void> _loadStoredCheckin() async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString(_prefsKey);
    if (s != null) {
      setState(() => checkInTime = DateTime.tryParse(s));
    }
  }

  Future<void> _storeCheckin(DateTime dt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, dt.toIso8601String());
  }

  Future<void> _clearCheckin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  String _fmtTime(DateTime dt) => DateFormat("HH:mm").format(dt);

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

  bool get _canCheckIn {
    final now = DateTime.now();
    final opensAt = widget.shiftStart.subtract(const Duration(minutes: 10));
    return now.isAfter(opensAt) && now.isBefore(widget.shiftEnd);
  }

  String get _checkInHint {
    final now = DateTime.now();
    final opensAt = widget.shiftStart.subtract(const Duration(minutes: 10));
    if (now.isAfter(widget.shiftEnd)) return "Shift ended";
    if (now.isBefore(opensAt)) {
      final diff = opensAt.difference(now);
      final mins = diff.inMinutes;
      return "Check-in opens in ${mins} min";
    }
    return "Check-in available";
  }

  Future<void> _sendCheckIn() async {
    if (!_canCheckIn) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_checkInHint)));
      return;
    }

    setState(() => loading = true);
    try {
      final now = DateTime.now();

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

      await _storeCheckin(now);
      setState(() => checkInTime = now);

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
    if (checkInTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("You must check in first.")));
      return;
    }

    setState(() => loading = true);
    try {
      final now = DateTime.now();

      final duration = now.difference(checkInTime!);
      final totalHours = duration.inMinutes / 60.0;
      final hourlyRate = _getHourlyRate();
      final amount = totalHours * hourlyRate;

      final venue = (placement["venueName"] ?? placement["venue"] ?? "")
          .toString();
      final role = (placement["roleTitle"] ?? placement["role"] ?? "")
          .toString();
      final dateStr = (placement["date"] ?? "").toString();
      final startTime = (placement["startTime"] ?? "").toString();
      final endTime = (placement["endTime"] ?? "").toString();

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
          "checkIn": _fmtTime(checkInTime!),
          "checkOut": _fmtTime(now),
          "totalHours": double.parse(totalHours.toStringAsFixed(2)),
          "amount": double.parse(amount.toStringAsFixed(2)),
        },
      );

      await _clearCheckin();
      setState(() => checkInTime = null);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Check-out sent ✅")));
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

  @override
  Widget build(BuildContext context) {
    final venue = (placement["venueName"] ?? placement["venue"] ?? "Venue")
        .toString();
    final role = (placement["roleTitle"] ?? placement["role"] ?? "Role")
        .toString();

    final isCheckedIn = checkInTime != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Check in/out")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              role,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(venue),
            const SizedBox(height: 12),
            Text(
              "Date: ${DateFormat('EEE, d MMM yyyy').format(widget.shiftStart)}",
            ),
            Text(
              "Time: ${DateFormat('HH:mm').format(widget.shiftStart)} - ${DateFormat('HH:mm').format(widget.shiftEnd)}",
            ),
            const SizedBox(height: 10),

            Text(
              _checkInHint,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _canCheckIn ? Colors.green : Colors.orange,
              ),
            ),

            const SizedBox(height: 18),

            if (isCheckedIn) ...[
              Text(
                "Checked in at: ${_fmtTime(checkInTime!)}",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
            ],

            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: loading || isCheckedIn || !_canCheckIn
                        ? null
                        : _sendCheckIn,
                    child: loading ? const Text("...") : const Text("Check In"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: loading || !isCheckedIn ? null : _sendCheckOut,
                    child: loading
                        ? const Text("...")
                        : const Text("Check Out"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
