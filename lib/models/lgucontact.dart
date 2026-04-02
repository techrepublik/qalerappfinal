import 'facility.dart';

class LGUContact {
  final String lgu;
  final String barName;
  final bool paid;
  final String munId;
  final String provId;
  final String bdrrmo;
  final bool conflict;
  final List<Facility> hotlines;
  final List<Facility> hospitals;

  LGUContact({
    required this.lgu,
    required this.barName,
    required this.paid,
    required this.munId,
    required this.provId,
    required this.bdrrmo,
    required this.conflict,
    required this.hotlines,
    required this.hospitals,
  });

  factory LGUContact.fromJson(Map<String, dynamic> json) {
    return LGUContact(
      lgu: json['lguName'] ?? '',
      barName: json['barName'] ?? '',
      paid: json['online']?['paid'] ?? false,
      munId: json['online']?['munId'] ?? '',
      provId: json['online']?['provId'] ?? '',
      bdrrmo: json['localhotlines']?['bdrrmo'] ?? '',
      conflict: false,
      hotlines: (json['hotlines'] as List<dynamic>?)
          ?.map((h) => Facility.fromJson(h))
          .toList() ?? [],
      hospitals: (json['hospitals'] as List<dynamic>?)
          ?.map((h) => Facility.fromJson(h))
          .toList() ?? [],
    );
  }
}