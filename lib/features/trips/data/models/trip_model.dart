class TripModel {
  final String id;
  final String date;
  final String type; // cycle, bus, buggy
  final String from;
  final String to;
  final String distance;
  final String duration;
  final String startTime;
  final String endTime;
  final String? calories;
  final String? avgSpeed;
  final String? elevation;
  final String? co2;
  final String paymentType; // subscription, paid, own_bike
  final String? plan;
  final String? price;
  final int coins;
  final String? vehicle;
  final String? buggyNumber;
  final String? routeNumber;
  final String? passengers;
  final String? stops;
  final String? seat;
  final double? startLat;
  final double? startLng;
  final double? endLat;
  final double? endLng;

  const TripModel({
    required this.id,
    required this.date,
    required this.type,
    required this.from,
    required this.to,
    required this.distance,
    required this.duration,
    required this.startTime,
    required this.endTime,
    this.calories,
    this.avgSpeed,
    this.elevation,
    this.co2,
    required this.paymentType,
    this.plan,
    this.price,
    this.coins = 0,
    this.vehicle,
    this.buggyNumber,
    this.routeNumber,
    this.passengers,
    this.stops,
    this.seat,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      type: json['type'] as String? ?? 'cycle',
      from: json['from'] as String? ?? '',
      to: json['to'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      startTime: json['start_time'] as String? ?? json['startTime'] as String? ?? '',
      endTime: json['end_time'] as String? ?? json['endTime'] as String? ?? '',
      calories: json['calories'] as String?,
      avgSpeed: json['avg_speed'] as String? ?? json['avgSpeed'] as String?,
      elevation: json['elevation'] as String?,
      co2: json['co2'] as String?,
      paymentType: json['payment_type'] as String? ?? json['paymentType'] as String? ?? 'paid',
      plan: json['plan'] as String?,
      price: json['price'] as String?,
      coins: (json['coins'] as num?)?.toInt() ?? 0,
      vehicle: json['vehicle'] as String?,
      buggyNumber: json['buggy_number'] as String? ?? json['buggyNumber'] as String?,
      routeNumber: json['route_number'] as String? ?? json['routeNumber'] as String?,
      passengers: json['passengers'] as String?,
      stops: json['stops'] as String?,
      seat: json['seat'] as String?,
      startLat: (json['start_lat'] as num?)?.toDouble() ?? (json['startLat'] as num?)?.toDouble(),
      startLng: (json['start_lng'] as num?)?.toDouble() ?? (json['startLng'] as num?)?.toDouble(),
      endLat: (json['end_lat'] as num?)?.toDouble() ?? (json['endLat'] as num?)?.toDouble(),
      endLng: (json['end_lng'] as num?)?.toDouble() ?? (json['endLng'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'type': type,
        'from': from,
        'to': to,
        'distance': distance,
        'duration': duration,
        'start_time': startTime,
        'end_time': endTime,
        'calories': calories,
        'avg_speed': avgSpeed,
        'elevation': elevation,
        'co2': co2,
        'payment_type': paymentType,
        'plan': plan,
        'price': price,
        'coins': coins,
        'vehicle': vehicle,
        'buggy_number': buggyNumber,
        'route_number': routeNumber,
        'passengers': passengers,
        'stops': stops,
        'seat': seat,
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
      };
}
