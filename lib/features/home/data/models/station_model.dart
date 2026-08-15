class StationModel {
  final String id;
  final String name;
  final double distance;
  final int walkMin;
  final int capacity;
  final int currentCapacity;
  final double lat;
  final double lng;

  const StationModel({
    required this.id,
    required this.name,
    this.distance = 0.0,
    this.walkMin = 0,
    this.capacity = 0,
    this.currentCapacity = 0,
    required this.lat,
    required this.lng,
  });

  /// Available docks = capacity - currentCapacity
  int get availableDocks => capacity - currentCapacity;

  factory StationModel.fromJson(Map<String, dynamic> json) {
    return StationModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      walkMin: (json['walk_min'] as num?)?.toInt() ?? 0,
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      currentCapacity: (json['current_capacity'] as num?)?.toInt() ?? 0,
      lat: _parseDouble(json['location_latitude'] ?? json['lat']),
      lng: _parseDouble(json['location_longitude'] ?? json['lng']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'distance': distance,
        'walk_min': walkMin,
        'capacity': capacity,
        'current_capacity': currentCapacity,
        'location_latitude': lat.toString(),
        'location_longitude': lng.toString(),
      };
}
