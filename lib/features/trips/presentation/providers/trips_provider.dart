import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/trip_model.dart';
import '../../data/repositories/trip_repository.dart';
import '../../data/repositories/trip_repository_impl.dart';
import '../../../../core/network/providers.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final tripRepositoryProvider = Provider<TripRepository>((ref) {
  return TripRepositoryImpl(ref.watch(apiClientProvider));
});

// ── State ────────────────────────────────────────────────────────────────────

class TripsState {
  final List<TripModel> trips;
  final List<TripModel> localTrips;
  final String? activeFilter;
  final bool isLoading;
  final String? error;

  const TripsState({
    this.trips = const [],
    this.localTrips = const [],
    this.activeFilter,
    this.isLoading = false,
    this.error,
  });

  TripsState copyWith({
    List<TripModel>? trips,
    List<TripModel>? localTrips,
    String? activeFilter,
    bool? isLoading,
    String? error,
  }) {
    return TripsState(
      trips: trips ?? this.trips,
      localTrips: localTrips ?? this.localTrips,
      activeFilter: activeFilter ?? this.activeFilter,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  List<TripModel> get mergedTrips {
    if (localTrips.isEmpty) return trips;
    final localIds = localTrips
        .where((trip) => trip.id.isNotEmpty)
        .map((trip) => trip.id)
        .toSet();
    return [
      ...localTrips,
      ...trips.where((trip) => trip.id.isEmpty || !localIds.contains(trip.id)),
    ];
  }

  List<TripModel> get filtered {
    final source = mergedTrips;
    if (activeFilter == null) return source;
    if (activeFilter == 'own_bike') {
      return source.where((t) => t.paymentType == 'own_bike').toList();
    }
    return source.where((t) => t.type == activeFilter).toList();
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class TripsNotifier extends StateNotifier<TripsState> {
  final TripRepository _repository;

  TripsNotifier(this._repository) : super(const TripsState()) {
    loadTrips();
  }

  Future<void> loadTrips() async {
    state = state.copyWith(isLoading: true);
    try {
      final trips = await _repository.getTrips(filter: state.activeFilter);
      state = state.copyWith(
        trips: trips,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Pull-to-refresh or post-ride invalidation entry point.
  Future<void> refresh() => loadTrips();

  void setFilter(String? filter) {
    state = state.copyWith(activeFilter: filter);
    loadTrips();
  }

  void upsertLocalTrip(TripModel trip) {
    final updated = [
      trip,
      ...state.localTrips.where((existing) => existing.id != trip.id),
    ];
    state = state.copyWith(localTrips: updated);
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final tripsProvider = StateNotifierProvider<TripsNotifier, TripsState>((ref) {
  return TripsNotifier(ref.watch(tripRepositoryProvider));
});
