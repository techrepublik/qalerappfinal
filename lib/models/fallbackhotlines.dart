// models/fallback_hotline_model.dart

class FallbackHotline {
  final String type;
  final String number;
  final String station;

  FallbackHotline({
    required this.type,
    required this.number,
    required this.station,
  });

  factory FallbackHotline.fromJson(Map<String, dynamic> json) {
    return FallbackHotline(
      type:    json['type']    ?? 'Unknown',
      number:  json['number']  ?? '',
      station: json['station'] ?? '',
    );
  }
}

class FallbackMunicipality {
  final String name;
  final String province;
  final List<FallbackHotline> hotlines;

  FallbackMunicipality({
    required this.name,
    required this.province,
    required this.hotlines,
  });

  factory FallbackMunicipality.fromJson(Map<String, dynamic> json) {
    final hotlines = (json['hotlines'] as List<dynamic>? ?? [])
        .map((h) => FallbackHotline.fromJson(h as Map<String, dynamic>))
        .toList();

    return FallbackMunicipality(
      name:     json['name']     ?? 'Unknown',
      province: json['province'] ?? '',
      hotlines: hotlines,
    );
  }
}