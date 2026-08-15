import 'package:flutter_test/flutter_test.dart';
import 'package:mjollnir_app/features/trips/presentation/providers/trips_provider.dart';
import 'package:mjollnir_app/features/trips/data/models/trip_model.dart';
import 'package:mjollnir_app/features/trips/data/repositories/trip_repository.dart';

class MockTripRepository implements TripRepository {
  bool shouldThrow = false;

  @override
  Future<List<TripModel>> getTrips({String? filter}) async {
    if (shouldThrow) throw Exception('Network error');
    return [
      const TripModel(id: '1', date: 'Today', type: 'cycle', from: 'A', to: 'B', distance: '2.3 km', duration: '12:05', startTime: '10:15', endTime: '10:27', paymentType: 'subscription', coins: 12),
      const TripModel(id: '2', date: 'Today', type: 'bus', from: 'C', to: 'D', distance: '1.5 km', duration: '06:20', startTime: '6:45', endTime: '6:51', paymentType: 'paid', coins: 6),
      const TripModel(id: '3', date: 'Yesterday', type: 'cycle', from: 'E', to: 'F', distance: '4.2 km', duration: '18:32', startTime: '7:00', endTime: '7:18', paymentType: 'own_bike', coins: 0),
    ];
  }

  @override
  Future<TripModel> getTripDetail(String tripId) async {
    if (shouldThrow) throw Exception('Not found');
    return const TripModel(id: '1', date: 'Today', type: 'cycle', from: 'A', to: 'B', distance: '2.3 km', duration: '12:05', startTime: '10:15', endTime: '10:27', paymentType: 'subscription');
  }
}

void main() {
  late MockTripRepository mockRepo;
  late TripsNotifier notifier;

  setUp(() {
    mockRepo = MockTripRepository();
    notifier = TripsNotifier(mockRepo);
  });

  group('TripsNotifier', () {
    test('loadTrips fetches and stores trips', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.trips.length, 3);
      expect(notifier.state.isLoading, isFalse);
    });

    test('setFilter updates active filter', () {
      notifier.setFilter('cycle');
      expect(notifier.state.activeFilter, 'cycle');
    });

    test('loadTrips sets error on failure', () async {
      mockRepo.shouldThrow = true;
      await notifier.loadTrips();

      expect(notifier.state.error, isNotNull);
    });
  });

  group('TripsState', () {
    test('filtered returns all when no filter', () async {
      await notifier.loadTrips();
      expect(notifier.state.filtered.length, 3);
    });

    test('filtered returns only matching type', () async {
      await notifier.loadTrips();
      notifier.setFilter('cycle');
      expect(notifier.state.filtered.length, 2);
    });

    test('filtered returns own_bike by paymentType', () async {
      await notifier.loadTrips();
      notifier.setFilter('own_bike');
      expect(notifier.state.filtered.length, 1);
      expect(notifier.state.filtered.first.id, '3');
    });

    test('filtered returns bus trips', () async {
      await notifier.loadTrips();
      notifier.setFilter('bus');
      expect(notifier.state.filtered.length, 1);
      expect(notifier.state.filtered.first.type, 'bus');
    });
  });

  group('TripModel', () {
    test('fromJson parses all fields', () {
      final json = {
        'id': 't1',
        'date': 'Today',
        'type': 'cycle',
        'from': 'Campus Gate',
        'to': 'Library',
        'distance': '2.3 km',
        'duration': '12:05',
        'start_time': '10:15 AM',
        'end_time': '10:27 AM',
        'calories': '69 cal',
        'avg_speed': '11.4 km/h',
        'co2': '0.46 kg',
        'payment_type': 'subscription',
        'coins': 12,
      };

      final trip = TripModel.fromJson(json);
      expect(trip.from, 'Campus Gate');
      expect(trip.calories, '69 cal');
      expect(trip.paymentType, 'subscription');
      expect(trip.coins, 12);
    });

    test('toJson round-trips correctly', () {
      const trip = TripModel(
        id: 't2',
        date: 'Today',
        type: 'bus',
        from: 'A',
        to: 'B',
        distance: '1 km',
        duration: '5:00',
        startTime: '8:00',
        endTime: '8:05',
        paymentType: 'paid',
        price: '₹12',
      );

      final json = trip.toJson();
      expect(json['type'], 'bus');
      expect(json['price'], '₹12');
      expect(json['payment_type'], 'paid');
    });
  });
}
