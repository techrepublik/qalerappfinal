class Alert {
  final String id;
  final String lguCode;
  final String userId;
  final String title;
  final AlertLocation location;
  final String emergencyType;
  final String status; // 'published' | 'draft'
  final DateTime createdAt;
  final DateTime updatedAt;

  Alert({
    required this.id,
    required this.lguCode,
    required this.userId,
    required this.title,
    required this.location,
    required this.emergencyType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      id: json['_id'] ?? '',
      lguCode: json['lguCode'] ?? '',
      userId: json['userId'] ?? '',
      title: json['title'] ?? '',
      location: AlertLocation.fromJson(json['location']),
      emergencyType: json['emergencyType'] ?? '',
      status: json['status'] ?? 'draft',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'lguCode': lguCode,
      'userId': userId,
      'title': title,
      'location': location.toJson(),
      'emergencyType': emergencyType,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

class AlertLocation {
  final String type; // always 'Point'
  final List<double> coordinates; // [longitude, latitude]
  final double? accuracy;

  AlertLocation({
    this.type = 'Point',
    required this.coordinates,
    this.accuracy,
  });

  /// Convenience getters
  double get longitude => coordinates[0];
  double get latitude => coordinates[1];

  factory AlertLocation.fromJson(Map<String, dynamic> json) {
    return AlertLocation(
      type: json['type'] ?? 'Point',
      coordinates: (json['coordinates'] as List<dynamic>)
          .map((c) => (c as num).toDouble())
          .toList(),
      accuracy: json['accuracy'] != null
          ? (json['accuracy'] as num).toDouble()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'coordinates': coordinates,
      if (accuracy != null) 'accuracy': accuracy,
    };
  }
}