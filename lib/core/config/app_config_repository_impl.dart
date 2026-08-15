import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/storage/local_storage.dart';
import 'app_config_model.dart';
import 'app_config_repository.dart';

class AppConfigRepositoryImpl implements AppConfigRepository {
  final ApiClient _api;

  /// SharedPreferences cache key for the last-fetched config JSON.
  static const _cacheKey = 'app_config_cache';

  AppConfigRepositoryImpl(this._api);

  @override
  Future<AppConfigModel> fetchConfig() async {
    try {
      final res = await _api.get(ApiEndpoints.config.fetch);
      final data = res.data['data'] as Map<String, dynamic>? ??
          res.data as Map<String, dynamic>;
      final config = AppConfigModel.fromJson(data);
      // Cache for offline / next cold-start
      await LocalStorage.setString(_cacheKey, jsonEncode(config.toJson()));
      return config;
    } catch (_) {
      // Return cached config if network fails, then fall back to defaults
      return _fromCache() ?? AppConfigModel.defaults;
    }
  }

  @override
  Future<RemoteLocationConfig> fetchLocationConfig(String locationId) async {
    final res = await _api.get(ApiEndpoints.config.locationConfig(locationId));
    final data = res.data['data'] as Map<String, dynamic>;
    return RemoteLocationConfig.fromJson(data);
  }

  /// Returns the last successfully fetched config from local cache, or null.
  AppConfigModel? _fromCache() {
    final raw = LocalStorage.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return AppConfigModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Returns the cached config synchronously without a network call.
  /// Useful when the UI needs a value before the async fetch completes.
  static AppConfigModel cachedOrDefaults() {
    final raw = LocalStorage.getString(_cacheKey);
    if (raw == null || raw.isEmpty) return AppConfigModel.defaults;
    try {
      return AppConfigModel.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppConfigModel.defaults;
    }
  }
}
