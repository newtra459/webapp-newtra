import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/station_model.dart';
import '../../data/repositories/home_repository.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../../../core/network/providers.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl(ref.watch(apiClientProvider));
});

class HomeState {
  final List<StationModel> stations;
  final StationModel? selectedStation;
  final bool isLoading;
  final String? error;

  const HomeState({
    this.stations = const [],
    this.selectedStation,
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({
    List<StationModel>? stations,
    StationModel? selectedStation,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      stations: stations ?? this.stations,
      selectedStation: selectedStation ?? this.selectedStation,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class HomeNotifier extends StateNotifier<HomeState> {
  final HomeRepository _repository;

  HomeNotifier(this._repository) : super(const HomeState());

  Future<void> loadStations(double lat, double lng) async {
    state = state.copyWith(isLoading: true);
    try {
      final stations = await _repository.getNearbyStations(lat, lng);
      state = state.copyWith(stations: stations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectStation(StationModel? station) {
    state = state.copyWith(selectedStation: station);
  }
}

final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(ref.watch(homeRepositoryProvider));
});
