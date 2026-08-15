// ============================================================
//  MJOLLNIR — REMOTE APP CONFIGURATION MODEL
//  lib/core/config/app_config_model.dart
//
//  The admin panel controls all of these values via the
//  backend.  The app fetches GET /config on launch and
//  caches the result so the UI reflects the latest
//  admin-published state without a re-deployment.
//
//  SHAPE (mirrors server JSON):
//  {
//    "features": { "ride": true, "transit": true, ... },
//    "transport": { "locations": [ { ... } ] },
//    "settings":  { "coin_conversion_rate": 1.0, ... }
//  }
// ============================================================

// ── Feature Flags ─────────────────────────────────────────────────────────────

/// One flag per app feature. Admin toggles these from the panel.
/// When a flag is false the corresponding tab / screen is hidden in the app.
class FeatureFlags {
  final bool ride;
  final bool transit;
  final bool wallet;
  final bool social;
  final bool groups;
  final bool subscriptions;
  final bool support;
  final bool activity;
  final bool trips;
  final bool profile;

  const FeatureFlags({
    this.ride          = true,
    this.transit       = true,
    this.wallet        = true,
    this.social        = true,
    this.groups        = true,
    this.subscriptions = true,
    this.support       = true,
    this.activity      = true,
    this.trips         = true,
    this.profile       = true,
  });

  /// All flags enabled — used as app fallback when config fetch fails.
  static const defaults = FeatureFlags();

  factory FeatureFlags.fromJson(Map<String, dynamic> json) {
    return FeatureFlags(
      ride:          json['ride']          as bool? ?? true,
      transit:       json['transit']       as bool? ?? true,
      wallet:        json['wallet']        as bool? ?? true,
      social:        json['social']        as bool? ?? true,
      groups:        json['groups']        as bool? ?? true,
      subscriptions: json['subscriptions'] as bool? ?? true,
      support:       json['support']       as bool? ?? true,
      activity:      json['activity']      as bool? ?? true,
      trips:         json['trips']         as bool? ?? true,
      profile:       json['profile']       as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'ride':          ride,
        'transit':       transit,
        'wallet':        wallet,
        'social':        social,
        'groups':        groups,
        'subscriptions': subscriptions,
        'support':       support,
        'activity':      activity,
        'trips':         trips,
        'profile':       profile,
      };
}

// ── Vehicle Config (Remote) ───────────────────────────────────────────────────

/// The payment model for a given vehicle type as set by the admin.
enum RemotePaymentModel {
  subscriptionIncluded,
  payAsYouGo,
  both;

  static RemotePaymentModel fromString(String s) {
    switch (s) {
      case 'subscription_included': return RemotePaymentModel.subscriptionIncluded;
      case 'pay_as_you_go':         return RemotePaymentModel.payAsYouGo;
      default:                      return RemotePaymentModel.both;
    }
  }

  String toJson() {
    switch (this) {
      case RemotePaymentModel.subscriptionIncluded: return 'subscription_included';
      case RemotePaymentModel.payAsYouGo:           return 'pay_as_you_go';
      case RemotePaymentModel.both:                 return 'both';
    }
  }
}

class RemoteVehicleConfig {
  /// e.g. 'bike' | 'ebike' | 'buggy' | 'bus'
  final String mode;
  final RemotePaymentModel paymentModel;
  final bool enabled;

  const RemoteVehicleConfig({
    required this.mode,
    required this.paymentModel,
    this.enabled = true,
  });

  factory RemoteVehicleConfig.fromJson(Map<String, dynamic> json) {
    return RemoteVehicleConfig(
      mode:         json['mode'] as String? ?? '',
      paymentModel: RemotePaymentModel.fromString(
          json['payment_model'] as String? ?? 'both'),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'mode':          mode,
        'payment_model': paymentModel.toJson(),
        'enabled':       enabled,
      };
}

// ── Location Config ───────────────────────────────────────────────────────────

/// Per-campus / per-zone configuration set by the admin.
class RemoteLocationConfig {
  final String id;
  final String name;
  final List<RemoteVehicleConfig> vehicles;
  final bool active;

  const RemoteLocationConfig({
    required this.id,
    required this.name,
    required this.vehicles,
    this.active = true,
  });

  /// Returns null if the mode is not in this location's vehicle list.
  RemoteVehicleConfig? vehicleFor(String mode) {
    try {
      return vehicles.firstWhere(
        (v) => v.mode == mode && v.enabled,
      );
    } catch (_) {
      return null;
    }
  }

  bool hasMode(String mode) => vehicleFor(mode) != null;

  factory RemoteLocationConfig.fromJson(Map<String, dynamic> json) {
    final rawVehicles = json['vehicles'] as List? ?? [];
    return RemoteLocationConfig(
      id:       json['id']   as String? ?? '',
      name:     json['name'] as String? ?? '',
      active:   json['active'] as bool? ?? true,
      vehicles: rawVehicles
          .map((v) => RemoteVehicleConfig.fromJson(v as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id':       id,
        'name':     name,
        'active':   active,
        'vehicles': vehicles.map((v) => v.toJson()).toList(),
      };
}

// ── Global Settings ───────────────────────────────────────────────────────────

/// Scalar settings that the admin can tune without a release.
class AppSettings {
  /// How many rupees 1 coin is worth when redeeming.
  final double coinConversionRate;

  /// Maximum ride duration in minutes before auto-end.
  final int maxRideDurationMin;

  /// Minimum wallet balance required to start a ride.
  final double minWalletBalanceForRide;

  /// Whether the coin/rewards system is globally active.
  final bool coinsEnabled;

  /// Whether social / leaderboard features are globally active.
  final bool leaderboardEnabled;

  /// Support chat mode: 'ai' | 'human' | 'both'
  final String supportChatMode;

  /// App-wide maintenance message (null = no maintenance).
  final String? maintenanceMessage;

  const AppSettings({
    this.coinConversionRate       = 1.0,
    this.maxRideDurationMin       = 120,
    this.minWalletBalanceForRide  = 0.0,
    this.coinsEnabled             = true,
    this.leaderboardEnabled       = true,
    this.supportChatMode          = 'both',
    this.maintenanceMessage,
  });

  static const defaults = AppSettings();

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      coinConversionRate: (json['coin_conversion_rate'] as num?)?.toDouble() ?? 1.0,
      maxRideDurationMin: (json['max_ride_duration_min'] as num?)?.toInt() ?? 120,
      minWalletBalanceForRide:
          (json['min_wallet_balance_for_ride'] as num?)?.toDouble() ?? 0.0,
      coinsEnabled:       json['coins_enabled']       as bool? ?? true,
      leaderboardEnabled: json['leaderboard_enabled'] as bool? ?? true,
      supportChatMode:    json['support_chat_mode']   as String? ?? 'both',
      maintenanceMessage: json['maintenance_message'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'coin_conversion_rate':        coinConversionRate,
        'max_ride_duration_min':       maxRideDurationMin,
        'min_wallet_balance_for_ride': minWalletBalanceForRide,
        'coins_enabled':               coinsEnabled,
        'leaderboard_enabled':         leaderboardEnabled,
        'support_chat_mode':           supportChatMode,
        'maintenance_message':         maintenanceMessage,
      };
}

// ── Root Config ───────────────────────────────────────────────────────────────

/// The full app configuration returned by GET /config.
/// Everything here is edited from the admin panel.
class AppConfigModel {
  final FeatureFlags features;
  final List<RemoteLocationConfig> locations;
  final AppSettings settings;

  const AppConfigModel({
    this.features  = const FeatureFlags(),
    this.locations = const [],
    this.settings  = const AppSettings(),
  });

  /// Safe fallback — all features on, no locations loaded.
  static const defaults = AppConfigModel();

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    final rawLocations =
        (json['transport'] as Map<String, dynamic>?)?['locations'] as List? ?? [];
    return AppConfigModel(
      features: FeatureFlags.fromJson(
          json['features'] as Map<String, dynamic>? ?? {}),
      locations: rawLocations
          .map((l) =>
              RemoteLocationConfig.fromJson(l as Map<String, dynamic>))
          .toList(),
      settings: AppSettings.fromJson(
          json['settings'] as Map<String, dynamic>? ?? {}),
    );
  }

  Map<String, dynamic> toJson() => {
        'features': features.toJson(),
        'transport': {
          'locations': locations.map((l) => l.toJson()).toList(),
        },
        'settings': settings.toJson(),
      };
}
