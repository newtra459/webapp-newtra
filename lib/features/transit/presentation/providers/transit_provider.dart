import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/transit_model.dart';
import '../../data/repositories/transit_repository.dart';
import '../../data/repositories/transit_repository_impl.dart';
import '../../../../core/network/providers.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final transitRepositoryProvider = Provider<TransitRepository>((ref) {
  return TransitRepositoryImpl(ref.watch(apiClientProvider));
});

// ── State ────────────────────────────────────────────────────────────────────

class TransitState {
  final List<TransitStopModel> busStops;
  final List<TransitStopModel> buggyStops;
  final TransitTripModel? activeTrip;
  final TransitTripModel? completedTrip;
  final bool isLoading;
  final bool isBoarding;
  final bool isEnding;
  final String? error;

  const TransitState({
    this.busStops = const [],
    this.buggyStops = const [],
    this.activeTrip,
    this.completedTrip,
    this.isLoading = false,
    this.isBoarding = false,
    this.isEnding = false,
    this.error,
  });

  TransitState copyWith({
    List<TransitStopModel>? busStops,
    List<TransitStopModel>? buggyStops,
    TransitTripModel? activeTrip,
    TransitTripModel? completedTrip,
    bool? isLoading,
    bool? isBoarding,
    bool? isEnding,
    String? error,
    bool clearActiveTrip = false,
    bool clearCompletedTrip = false,
  }) {
    return TransitState(
      busStops: busStops ?? this.busStops,
      buggyStops: buggyStops ?? this.buggyStops,
      activeTrip: clearActiveTrip ? null : (activeTrip ?? this.activeTrip),
      completedTrip: clearCompletedTrip ? null : (completedTrip ?? this.completedTrip),
      isLoading: isLoading ?? this.isLoading,
      isBoarding: isBoarding ?? this.isBoarding,
      isEnding: isEnding ?? this.isEnding,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class TransitNotifier extends StateNotifier<TransitState> {
  final TransitRepository _repository;

  TransitNotifier(this._repository) : super(const TransitState()) {
    loadStops();
    checkActiveTrip();
  }

  Future<void> loadStops({String? search}) async {
    state = state.copyWith(isLoading: true);
    try {
      List<TransitStopModel> bus = [];
      List<TransitStopModel> buggy = [];
      try { bus = await _repository.getNearbyStops(type: 'bus', search: search); } catch (_) {}
      try { buggy = await _repository.getNearbyStops(type: 'buggy', search: search); } catch (_) {}
      state = state.copyWith(
        busStops: bus,
        buggyStops: buggy,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<TransitTripModel?> checkActiveTrip() async {
    try {
      final trip = await _repository.getActiveTrip();
      state = state.copyWith(activeTrip: trip, clearActiveTrip: trip == null);
      return trip;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<TransitTripModel?> boardVehicle({
    required String vehicleId,
    required String stopId,
  }) async {
    state = state.copyWith(isBoarding: true, error: null);
    try {
      final trip = await _repository.boardVehicle(
        vehicleId: vehicleId,
        stopId: stopId,
      );
      state = state.copyWith(activeTrip: trip, isBoarding: false, error: null);
      return trip;
    } catch (e) {
      state = state.copyWith(isBoarding: false, error: e.toString());
      return null;
    }
  }

  Future<TransitTripModel?> endTrip(String tripId) async {
    state = state.copyWith(isEnding: true);
    try {
      final trip = await _repository.endTrip(tripId);
      state = state.copyWith(
        completedTrip: trip,
        isEnding: false,
        clearActiveTrip: true,
      );
      return trip;
    } catch (e) {
      state = state.copyWith(isEnding: false, error: e.toString());
      return null;
    }
  }

  void clearCompletedTrip() {
    state = state.copyWith(clearCompletedTrip: true);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final transitProvider = StateNotifierProvider<TransitNotifier, TransitState>((ref) {
  return TransitNotifier(ref.watch(transitRepositoryProvider));
});
