import 'dart:math';



class Hospital {
  final String name;
  final String address;
  final String phone;
  final String? facebookURI;
  final String? websiteURL;
  final Map<String, double> coordinates;

  Hospital({required this.name, required this.address, required this.phone,
    required this.coordinates, this.facebookURI,
    this.websiteURL,});

  factory Hospital.fromJson(Map<String, dynamic> json) {
    return Hospital(
      name: json['name'],
      address: json['address'],
      phone: json['phone'],
      facebookURI: json['facebookURI'],
      websiteURL: json['websiteURL'],

      coordinates: {
        'lat': json['coordinates']['lat'].toDouble(),
        'lng': json['coordinates']['lng'].toDouble(),
      },
    );
  }

  double calculateDistance(double userLat, double userLng) {
    const double earthRadius = 6371;
    double dLat = (coordinates['lat']! - userLat) * pi / 180;
    double dLon = (coordinates['lng']! - userLng) * pi / 180;

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(userLat * pi / 180) * cos(coordinates['lat']! * pi / 180) *
            sin(dLon / 2) * sin(dLon / 2);

    return earthRadius * 2 * asin(sqrt(a));
  }
}