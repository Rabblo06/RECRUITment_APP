class Placement {
  final String id;
  final String hotelName;
  final String position;
  final DateTime date;
  final String startTime;
  final String endTime;
  final double hourlyRate;
  final double hours;
  final String address;
  final String notes;
  final String status; // "New Offer", "Waiting List", "Booking Confirmed" etc.

  const Placement({
    required this.id,
    required this.hotelName,
    required this.position,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.hourlyRate,
    required this.hours,
    required this.address,
    required this.notes,
    required this.status,
  });

  double get potentialEarnings => hourlyRate * hours;
}
