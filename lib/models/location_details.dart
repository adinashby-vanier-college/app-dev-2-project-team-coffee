class LocationDetails {
  final String id;
  final String name;
  final double rating;
  final String reviews;
  final String? price;
  final String category;
  final String address;
  final String? openStatus;
  final String? closeTime;
  final String? phone;
  final String? website;
  final String description;
  final List<DayHours> hours;

  LocationDetails({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviews,
    required this.category,
    required this.address,
    required this.description,
    required this.hours,
    this.price,
    this.openStatus,
    this.closeTime,
    this.phone,
    this.website,
  });
}

class DayHours {
  final String day;
  final String time;

  DayHours({required this.day, required this.time});
}

