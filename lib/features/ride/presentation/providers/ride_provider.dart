import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/ride_model.dart';
import '../../data/repositories/ride_repository.dart';
import '../../data/repositories/ride_repository_impl.dart';
import '../../../../core/network/providers.dart';
import '../../../../core/storage/local_storage.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepositoryImpl(ref.watch(apiClientProvider));
});

// ── State ────────────────────────────────────────────────────────────────────

enum RideStatus { idle, starting, active, paused, ending, ended, error }

class RideState {
  final RideStatus status;
  final RideModel? ride;
  final String? error;

  const RideState({
    this.status = RideStatus.idle,
    this.ride,
    this.error,
  });

  RideState copyWith({
    RideStatus? status,
    RideModel? ride,
    String? error,
  }) {
    return RideState(
      status: status ?? this.status,
      ride: ride ?? this.ride,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class RideNotifier extends StateNotifier<RideState> {
  final RideRepository _repository;

  RideNotifier(this._repository) : super(const RideState());

  Future<bool> startRide({required String bikeId, required int rideMode, bool isEBike = true}) async {
    state = state.copyWith(status: RideStatus.starting);
    try {
      final ride = await _repository.startRide(bikeId: bikeId, rideMode: rideMode, isEBike: isEBike);
      // Persist the server-assigned ride ID so it survives app restarts
      // and is available when the user taps "End Ride".
      if (ride.id.isNotEmpty) {
        await LocalStorage.saveActiveRideServerId(ride.id);
      }
      state = state.copyWith(status: RideStatus.active, ride: ride);
      return true;
    } catch (e) {
      state = state.copyWith(status: RideStatus.error, error: e.toString());
      return false;
    }
  }

  Future<RideModel?> endRide() async {
    if (state.ride == null) return null;
    state = state.copyWith(status: RideStatus.ending);
    try {
      final result = await _repository.endRide(state.ride!.id);
      state = state.copyWith(status: RideStatus.ended, ride: result);
      return result;
    } catch (e) {
      state = state.copyWith(status: RideStatus.error, error: e.toString());
      return null;
    }
  }

  void pauseRide() {
    if (state.status == RideStatus.active) {
      state = state.copyWith(status: RideStatus.paused);
    }
  }

  void resumeRide() {
    if (state.status == RideStatus.paused) {
      state = state.copyWith(status: RideStatus.active);
    }
  }

  void updateLocalMetrics({double? distance, double? speed, double? calories, double? elevation, double? lat, double? lng}) {
    if (state.ride == null) return;
    state = state.copyWith(
      ride: state.ride!.copyWith(
        distance: distance ?? state.ride!.distance,
        currentSpeed: speed ?? state.ride!.currentSpeed,
        maxSpeed: speed != null && speed > state.ride!.maxSpeed ? speed : state.ride!.maxSpeed,
        calories: calories ?? state.ride!.calories,
        elevation: elevation ?? state.ride!.elevation,
        lat: lat ?? state.ride!.lat,
        lng: lng ?? state.ride!.lng,
      ),
    );
  }

  void reset() => state = const RideState();
}

// ── Provider ─────────────────────────────────────────────────────────────────

final rideProvider = StateNotifierProvider<RideNotifier, RideState>((ref) {
  return RideNotifier(ref.watch(rideRepositoryProvider));
});
