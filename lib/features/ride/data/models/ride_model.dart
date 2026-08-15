class RideModel {
  final String id;
  final int rideMode; // 0 = shared, 1 = own bike
  final bool isEBike;
  final int seconds;
  final double distance;
  final double currentSpeed;
  final double maxSpeed;
  final double calories;
  final double elevation;
  final double lat;
  final double lng;
  final List<List<double>> routePoints;
  final String bikeId;
  final int batteryPct;
  final bool paidWithCoin;

  const RideModel({
    this.id = '',
    this.rideMode = 0,
    this.isEBike = true,
    this.seconds = 0,
    this.distance = 0.0,
    this.currentSpeed = 0.0,
    this.maxSpeed = 0.0,
    this.calories = 0.0,
    this.elevation = 0.0,
    this.lat = 0.0,
    this.lng = 0.0,
    this.routePoints = const [],
    this.bikeId = '',
    this.batteryPct = 100,
    this.paidWithCoin = false,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    final routePoints = _parseRoutePoints(
      json['route_points'] ?? json['routePoints'] ?? json['path'],
    );
    final currentLocation = json['current_location'];
    final currentLocationMap = currentLocation is Map
        ? Map<String, dynamic>.from(currentLocation)
        : null;
    final longestRide = json['longest_ride'];
    final longestRideMap = longestRide is Map
        ? Map<String, dynamic>.from(longestRide)
        : null;
    final lastRoutePoint = routePoints.isNotEmpty ? routePoints.last : null;

    return RideModel(
      id: json['id'] as String? ?? json['trip_id'] as String? ?? '',
      rideMode: _readInt(json['ride_mode']) ?? 0,
      isEBike: json['is_ebike'] as bool? ?? true,
      seconds:
          _readInt(json['seconds']) ??
          _readInt(json['duration_seconds']) ??
          _hoursToSeconds(json['total_time_hours']) ??
          0,
      distance:
          _readDouble(json['distance']) ??
          _readDouble(json['distance_km']) ??
          _readDouble(longestRideMap?['distance_km']) ??
          0.0,
      currentSpeed:
          _readDouble(json['current_speed']) ??
          _readDouble(json['current_speed_kmh']) ??
          _readDouble(json['speed']) ??
          _readDouble(json['average_speed']) ??
          _readDouble(json['highest_speed']) ??
          0.0,
      maxSpeed:
          _readDouble(json['max_speed']) ??
          _readDouble(json['max_speed_kmh']) ??
          _readDouble(json['highest_speed']) ??
          _readDouble(json['average_speed']) ??
          0.0,
      calories:
          _readDouble(json['calories']) ??
          _readDouble(json['kcal']) ??
          _readDouble(json['total_calories']) ??
          0.0,
      elevation:
          _readDouble(json['elevation']) ??
          _readDouble(json['max_elevation']) ??
          _readDouble(json['max_elevation_m']) ??
          0.0,
      lat:
          _readDouble(json['lat']) ??
          _readDouble(json['latitude']) ??
          _readDouble(currentLocationMap?['lat']) ??
          _readDouble(currentLocationMap?['latitude']) ??
          lastRoutePoint?.first ??
          0.0,
      lng:
          _readDouble(json['lng']) ??
          _readDouble(json['long']) ??
          _readDouble(json['longitude']) ??
          _readDouble(currentLocationMap?['lng']) ??
          _readDouble(currentLocationMap?['long']) ??
          _readDouble(currentLocationMap?['longitude']) ??
          (lastRoutePoint != null && lastRoutePoint.length > 1
              ? lastRoutePoint[1]
              : null) ??
          0.0,
      routePoints: routePoints,
      bikeId: json['bike_id'] as String? ?? '',
      batteryPct: _readInt(json['battery_pct']) ?? 100,
      paidWithCoin: json['paid_with_coin'] as bool? ?? false,
    );
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static int? _hoursToSeconds(dynamic value) {
    final hours = _readDouble(value);
    if (hours == null) return null;
    return (hours * 3600).round();
  }

  static List<List<double>> _parseRoutePoints(dynamic raw) {
    if (raw is! List) return const [];

    final points = <List<double>>[];
    for (final entry in raw) {
      double? lat;
      double? lng;
      if (entry is List && entry.length >= 2) {
        lat = _readDouble(entry[0]);
        lng = _readDouble(entry[1]);
      } else if (entry is Map) {
        lat = _readDouble(entry['lat']) ?? _readDouble(entry['latitude']);
        lng =
            _readDouble(entry['lng']) ??
            _readDouble(entry['long']) ??
            _readDouble(entry['longitude']);
      }

      if (lat == null || lng == null) continue;
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) continue;
      points.add([lat, lng]);
    }

    final hasRealPoint = points.any((point) => !_isFallbackPoint(point));
    if (!hasRealPoint) return points;
    return points.where((point) => !_isFallbackPoint(point)).toList();
  }

  static bool _isFallbackPoint(List<double> point) {
    if (point.length < 2) return false;
    return (point[0] - 17.4577).abs() < 0.00025 &&
        (point[1] - 78.2753).abs() < 0.00025;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'ride_mode': rideMode,
    'is_ebike': isEBike,
    'seconds': seconds,
    'distance': distance,
    'current_speed': currentSpeed,
    'max_speed': maxSpeed,
    'calories': calories,
    'elevation': elevation,
    'lat': lat,
    'lng': lng,
    'bike_id': bikeId,
    'battery_pct': batteryPct,
    'paid_with_coin': paidWithCoin,
  };

  RideModel copyWith({
    String? id,
    int? rideMode,
    bool? isEBike,
    int? seconds,
    double? distance,
    double? currentSpeed,
    double? maxSpeed,
    double? calories,
    double? elevation,
    double? lat,
    double? lng,
    List<List<double>>? routePoints,
    String? bikeId,
    int? batteryPct,
    bool? paidWithCoin,
  }) {
    return RideModel(
      id: id ?? this.id,
      rideMode: rideMode ?? this.rideMode,
      isEBike: isEBike ?? this.isEBike,
      seconds: seconds ?? this.seconds,
      distance: distance ?? this.distance,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      maxSpeed: maxSpeed ?? this.maxSpeed,
      calories: calories ?? this.calories,
      elevation: elevation ?? this.elevation,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      routePoints: routePoints ?? this.routePoints,
      bikeId: bikeId ?? this.bikeId,
      batteryPct: batteryPct ?? this.batteryPct,
      paidWithCoin: paidWithCoin ?? this.paidWithCoin,
    );
  }
}
