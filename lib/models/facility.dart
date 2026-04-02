import 'dart:math';

class Facility {
  final String name;
  final String address;
  final String contact;
  final String contact2;
  final List<double>? coordinates; // [latitude, longitude]

  Facility({
    required this.name,
    required this.address,
    required this.contact,
    this.contact2 = '',
    this.coordinates,
  });

  factory Facility.fromJson(Map<String, dynamic> json) {
    List<double>? coords;
    if (json['coordinates'] != null) {
      final coordList = json['coordinates'] as List<dynamic>;
      coords = coordList.map((e) => (e as num).toDouble()).toList();
    }

    return Facility(
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      contact: json['contact'] as String? ?? '',
      contact2: json['contact2'] as String? ?? '',
      coordinates: coords,
    );
  }

  // Calculate distance from current location (in kilometers)
  double? getDistanceFrom(double? currentLat, double? currentLon) {
    if (currentLat == null || currentLon == null || coordinates == null || coordinates!.length < 2) {
      return null;
    }

    return _calculateDistance(currentLat, currentLon, coordinates![0], coordinates![1]);
  }

  // Haversine formula for calculating distance between two points
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _toRadians(lat2 - lat1);
    final double dLon = _toRadians(lon2 - lon1);

    final double a =
        sin(dLat / 2) * sin(dLat / 2) +
            cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
                sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * pi / 180;
  }
}