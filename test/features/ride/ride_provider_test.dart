import 'package:flutter_test/flutter_test.dart';
import 'package:mjollnir_app/features/ride/presentation/providers/ride_provider.dart';
import 'package:mjollnir_app/features/ride/data/models/ride_model.dart';
import 'package:mjollnir_app/features/ride/data/repositories/ride_repository.dart';

class MockRideRepository implements RideRepository {
  bool shouldThrow = false;

  @override
  Future<RideModel> startRide({required String bikeId, required int rideMode, bool isEBike = true}) async {
    if (shouldThrow) throw Exception('Start failed');
    return RideModel(id: 'ride-1', bikeId: bikeId, rideMode: rideMode, isEBike: isEBike);
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
    if (shouldThrow) throw Exception('End failed');
    return RideModel(id: rideId, distance: 5.2, seconds: 600, calories: 150);
  }

  @override
  Future<void> validateBike(String bikeId) async {
    if (shouldThrow) throw Exception('Bike validation failed');
  }

  @override
  Future<void> updateRideLocation(
    String rideId,
    double lat,
    double lng, {
    double elevation = 0,
  }) async {}

  @override
  Future<void> batchUpdateLocations(
    String rideId,
    List<LocationBatchPoint> points,
  ) async {}

  @override
  Future<List<List<double>>?> getSnappedRoute(String tripId) async => null;
}

void main() {
  late MockRideRepository mockRepo;
  late RideNotifier notifier;

  setUp(() {
    mockRepo = MockRideRepository();
    notifier = RideNotifier(mockRepo);
  });

  group('RideNotifier', () {
    test('starts idle', () {
      expect(notifier.state.status, RideStatus.idle);
      expect(notifier.state.ride, isNull);
    });

    test('startRide transitions to active', () async {
      final success = await notifier.startRide(bikeId: 'MJ-001', rideMode: 0);

      expect(success, isTrue);
      expect(notifier.state.status, RideStatus.active);
      expect(notifier.state.ride?.bikeId, 'MJ-001');
    });

    test('startRide transitions to error on failure', () async {
      mockRepo.shouldThrow = true;
      final success = await notifier.startRide(bikeId: 'MJ-001', rideMode: 0);

      expect(success, isFalse);
      expect(notifier.state.status, RideStatus.error);
    });

    test('endRide returns completed ride', () async {
      await notifier.startRide(bikeId: 'MJ-001', rideMode: 0);
      final result = await notifier.endRide();

      expect(result, isNotNull);
      expect(notifier.state.status, RideStatus.ended);
      expect(result?.distance, 5.2);
    });

    test('endRide returns null when no ride', () async {
      final result = await notifier.endRide();
      expect(result, isNull);
    });

    test('pause and resume toggle status', () async {
      await notifier.startRide(bikeId: 'MJ-001', rideMode: 0);

      notifier.pauseRide();
      expect(notifier.state.status, RideStatus.paused);

      notifier.resumeRide();
      expect(notifier.state.status, RideStatus.active);
    });

    test('updateLocalMetrics updates ride data', () async {
      await notifier.startRide(bikeId: 'MJ-001', rideMode: 0);
      notifier.updateLocalMetrics(distance: 1.5, speed: 15.0, calories: 45.0);

      expect(notifier.state.ride?.distance, 1.5);
      expect(notifier.state.ride?.currentSpeed, 15.0);
      expect(notifier.state.ride?.maxSpeed, 15.0);
    });

    test('updateLocalMetrics tracks max speed', () async {
      await notifier.startRide(bikeId: 'MJ-001', rideMode: 0);
      notifier.updateLocalMetrics(speed: 20.0);
      notifier.updateLocalMetrics(speed: 10.0);

      expect(notifier.state.ride?.maxSpeed, 20.0);
    });

    test('reset clears state', () async {
      await notifier.startRide(bikeId: 'MJ-001', rideMode: 0);
      notifier.reset();

      expect(notifier.state.status, RideStatus.idle);
      expect(notifier.state.ride, isNull);
    });
  });

  group('RideModel', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'r1',
        'bike_id': 'MJ-042',
        'ride_mode': 0,
        'is_ebike': true,
        'distance': 3.5,
        'max_speed': 22.1,
        'calories': 105.0,
      };

      final ride = RideModel.fromJson(json);
      expect(ride.id, 'r1');
      expect(ride.bikeId, 'MJ-042');
      expect(ride.distance, 3.5);
    });

    test('copyWith preserves unchanged fields', () {
      const ride = RideModel(id: 'r1', bikeId: 'MJ-001', distance: 5.0);
      final updated = ride.copyWith(distance: 6.0);

      expect(updated.distance, 6.0);
      expect(updated.bikeId, 'MJ-001');
    });
  });
}
