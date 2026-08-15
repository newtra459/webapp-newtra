// Transit data models — stops (nearest vehicles) and trip sessions.

// ── Transit Stop ──────────────────────────────────────────────────────────────

class TransitStopModel {
  final String id;
  final String name;
  final String route;       // e.g. "Route 1 · City Loop"
  final String routeShort;  // e.g. "R1"
  final String eta;         // e.g. "3 min"
  final int capacityOccupied;
  final int capacityTotal;
  final List<String> nextEtas;
  final String type;        // 'bus' | 'buggy'
  final String distance;    // e.g. "0.2 km"
  final String vehicleId;
  final String vehicleName;
  final String vehicleNumber;
  final String? vehicleImageUrl;
  final double lat;
  final double lng;

  const TransitStopModel({
    this.id = '',
    this.name = '',
    this.route = '',
    this.routeShort = '',
    this.eta = '',
    this.capacityOccupied = 0,
    this.capacityTotal = 0,
    this.nextEtas = const [],
    this.type = 'bus',
    this.distance = '',
    this.vehicleId = '',
    this.vehicleName = '',
    this.vehicleNumber = '',
    this.vehicleImageUrl,
    this.lat = 0.0,
    this.lng = 0.0,
  });

  factory TransitStopModel.fromJson(Map<String, dynamic> json) {
    final nextRaw = json['next_etas'] as List? ?? json['nextEtas'] as List? ?? [];
    return TransitStopModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      route: json['route'] as String? ?? '',
      routeShort: json['route_short'] as String? ?? json['routeShort'] as String? ?? '',
      eta: json['eta'] as String? ?? '',
      capacityOccupied: (json['capacity_occupied'] as num?)?.toInt() ??
          (json['capacity'] as num?)?.toInt() ?? 0,
      capacityTotal: (json['capacity_total'] as num?)?.toInt() ??
          (json['total'] as num?)?.toInt() ?? 0,
      nextEtas: nextRaw.map((e) => e.toString()).toList(),
      type: json['type'] as String? ?? 'bus',
      distance: json['distance'] as String? ?? '',
      vehicleId: json['vehicle_id'] as String? ?? json['vehicleId'] as String? ?? '',
      vehicleName: json['vehicle_name'] as String? ?? json['vehicleName'] as String? ?? '',
      vehicleNumber: json['vehicle_number'] as String? ?? json['vehicleNumber'] as String? ?? '',
      vehicleImageUrl: json['vehicle_image_url'] as String? ?? json['vehicleImageUrl'] as String?,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'route': route,
        'route_short': routeShort,
        'eta': eta,
        'capacity_occupied': capacityOccupied,
        'capacity_total': capacityTotal,
        'next_etas': nextEtas,
        'type': type,
        'distance': distance,
        'vehicle_id': vehicleId,
        'vehicle_name': vehicleName,
        'vehicle_number': vehicleNumber,
        'vehicle_image_url': vehicleImageUrl,
        'lat': lat,
        'lng': lng,
      };
}

// ── Transit Trip ──────────────────────────────────────────────────────────────

class TransitTripModel {
  final String id;
  final String stopName;
  final String type;          // 'bus' | 'buggy'
  final String route;
  final String vehicleName;
  final String vehicleNumber;
  final String? vehicleImageUrl;
  final String startTime;     // ISO-8601 timestamp
  final String? endTime;      // null while trip is active
  final int elapsedSeconds;
  final int xpEarned;
  final double? fare;

  const TransitTripModel({
    this.id = '',
    this.stopName = '',
    this.type = 'bus',
    this.route = '',
    this.vehicleName = '',
    this.vehicleNumber = '',
    this.vehicleImageUrl,
    this.startTime = '',
    this.endTime,
    this.elapsedSeconds = 0,
    this.xpEarned = 0,
    this.fare,
  });

  factory TransitTripModel.fromJson(Map<String, dynamic> json) {
    return TransitTripModel(
      id: json['id'] as String? ?? '',
      stopName: json['stop_name'] as String? ?? json['stopName'] as String? ?? '',
      type: json['type'] as String? ?? 'bus',
      route: json['route'] as String? ?? '',
      vehicleName: json['vehicle_name'] as String? ?? json['vehicleName'] as String? ?? '',
      vehicleNumber: json['vehicle_number'] as String? ?? json['vehicleNumber'] as String? ?? '',
      vehicleImageUrl: json['vehicle_image_url'] as String? ?? json['vehicleImageUrl'] as String?,
      startTime: json['start_time'] as String? ?? json['startTime'] as String? ?? '',
      endTime: json['end_time'] as String? ?? json['endTime'] as String?,
      elapsedSeconds: (json['elapsed_seconds'] as num?)?.toInt() ?? 0,
      xpEarned: (json['xp_earned'] as num?)?.toInt() ?? 0,
      fare: (json['fare'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'stop_name': stopName,
        'type': type,
        'route': route,
        'vehicle_name': vehicleName,
        'vehicle_number': vehicleNumber,
        'vehicle_image_url': vehicleImageUrl,
        'start_time': startTime,
        'end_time': endTime,
        'elapsed_seconds': elapsedSeconds,
        'xp_earned': xpEarned,
        'fare': fare,
      };
}
