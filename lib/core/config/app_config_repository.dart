import 'app_config_model.dart';

abstract class AppConfigRepository {
  /// GET /config — Full app config (feature flags + transport + settings).
  /// Call once on app launch; the result drives every feature gate.
  Future<AppConfigModel> fetchConfig();

  /// GET /config/locations/:id — Config for a single location.
  /// Use this to refresh a specific campus without re-fetching everything.
  Future<RemoteLocationConfig> fetchLocationConfig(String locationId);
}
