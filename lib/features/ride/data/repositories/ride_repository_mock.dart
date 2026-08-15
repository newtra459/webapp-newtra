// Dummy data mock — swap back to RideRepositoryImpl in ride_provider.dart
// when the backend /rides endpoint is live.

import '../models/ride_model.dart';
import 'ride_repository.dart';

class RideRepositoryMock implements RideRepository {
  int _rideCounter = 0;

  @override
  Future<void> validateBike(String bikeId) async {
    await Future.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<RideModel> startRide({
    required String bikeId,
    required int rideMode,
    bool isEBike = true,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    _rideCounter++;
    return RideModel(
      id: 'mock-ride-$_rideCounter',
      rideMode: rideMode,
      isEBike: isEBike,
      seconds: 0,
      distance: 0.0,
      currentSpeed: 0.0,
      maxSpeed: 0.0,
      calories: 0.0,
      elevation: 0.0,
      lat: 17.4577,
      lng: 78.2753,
      bikeId: bikeId,
      batteryPct: isEBike ? 82 : 100,
      paidWithCoin: false,
    );
  }

  @override
  Future<RideModel> endRide(String rideId, {
    bool personal = false,
    double distance = 0,
    double duration = 0,
    double averageSpeed = 0,
    double kcal = 0,
    double maxElevation = 0,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    // Return a finalised ride snapshot (realistic values for summary screen)
    // with sample GPS route points
    const List<List<double>> sampleRoute = [
      [17.4577, 78.2753],  // Main Gate
      [17.4580, 78.2758],
      [17.4585, 78.2765],
      [17.4590, 78.2772],  // Approaching Library
      [17.4595, 78.2778],
      [17.4598, 78.2785],
      [17.4602, 78.2790],
      [17.4605, 78.2798],
      [17.4608, 78.2805],
      [17.4610, 78.2815],  // Library Hub Area
      [17.4612, 78.2820],
      [17.4615, 78.2825],
      [17.4618, 78.2828],
      [17.4620, 78.2832],
      [17.4625, 78.2835],
      [17.4630, 78.2838],  // Heading towards destination
      [17.4633, 78.2842],
      [17.4635, 78.2848],
      [17.4638, 78.2852],
      [17.4640, 78.2858],
      [17.4642, 78.2862],
      [17.4645, 78.2868],
      [17.4648, 78.2872],
      [17.4650, 78.2878],
      [17.4652, 78.2885],
      [17.4655, 78.2890],
      [17.4658, 78.2895],
      [17.4660, 78.2900],
      [17.4662, 78.2905],
      [17.4665, 78.2910],
      [17.4667, 78.2915],
      [17.4670, 78.2920],
      [17.4672, 78.2925],
      [17.4673, 78.2930],  // Sports Complex
    ];
    
    return const RideModel(
      id: 'mock-ride-ended',
      rideMode: 0,
      isEBike: true,
      seconds: 427,
      distance: 1.2,
      currentSpeed: 0.0,
      maxSpeed: 11.4,
      calories: 38.5,
      elevation: 4.0,
      lat: 17.4673,
      lng: 78.2930,
      routePoints: sampleRoute,
      bikeId: 'B14',
      batteryPct: 79,
      paidWithCoin: false,
    );
  }

  @override
  Future<void> updateRideLocation(
    String rideId,
    double lat,
    double lng, {
    double elevation = 0,
  }) async {
    // No-op in mock — location tracking is local-only during a ride
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<void> batchUpdateLocations(
    String rideId,
    List<LocationBatchPoint> points,
  ) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Future<List<List<double>>?> getSnappedRoute(String tripId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return null;
  }

  @override
  Future<RideModel?> getActiveRide() async {
    await Future.delayed(const Duration(milliseconds: 100));
    return null;
  }
}
