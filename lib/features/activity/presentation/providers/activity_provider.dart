import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/activity_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/activity_repository_impl.dart';
import '../../../../core/network/providers.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepositoryImpl(ref.watch(apiClientProvider));
});

class ActivityState {
  final ActivitySummary summary;
  final String selectedPeriod;
  final bool isLoading;
  final String? error;
  final Map<String, List<GraphDataPoint>> graphData;

  const ActivityState({
    this.summary = const ActivitySummary(),
    this.selectedPeriod = 'week',
    this.isLoading = false,
    this.error,
    this.graphData = const {},
  });

  ActivityState copyWith({
    ActivitySummary? summary,
    String? selectedPeriod,
    bool? isLoading,
    String? error,
    Map<String, List<GraphDataPoint>>? graphData,
  }) {
    return ActivityState(
      summary: summary ?? this.summary,
      selectedPeriod: selectedPeriod ?? this.selectedPeriod,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      graphData: graphData ?? this.graphData,
    );
  }
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  final ActivityRepository _repository;

  ActivityNotifier(this._repository) : super(const ActivityState()) {
    loadSummary();
  }

  Future<void> loadSummary() async {
    state = state.copyWith(isLoading: true);
    try {
      final summary = await _repository.getSummary(period: state.selectedPeriod);
      state = state.copyWith(summary: summary, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setPeriod(String period) {
    state = state.copyWith(selectedPeriod: period);
    loadSummary();
  }

  /// Load graph data for a given date range
  Future<Map<String, List<GraphDataPoint>>> loadGraphData(
    String startDate,
    String endDate,
  ) async {
    try {
      final results = await Future.wait([
        _repository.getDistanceGraph(startDate, endDate),
        _repository.getCaloriesGraph(startDate, endDate),
        _repository.getTimeGraph(startDate, endDate),
      ]);
      final graphData = {
        'distance': results[0],
        'calories': results[1],
        'time': results[2],
      };
      state = state.copyWith(graphData: graphData);
      return graphData;
    } catch (_) {
      state = state.copyWith(graphData: const {});
      return const {};
    }
  }
}

final activityProvider = StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  return ActivityNotifier(ref.watch(activityRepositoryProvider));
});
