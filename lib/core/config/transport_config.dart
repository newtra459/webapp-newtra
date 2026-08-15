// Defines per-location transport vehicle configuration.
//
// The static _configs map below is the LOCAL FALLBACK used only when the
// remote config hasn't been fetched yet (first cold-start with no cache).
//
// At runtime, call TransportRegistry.applyRemoteConfig(locations) after
// AppConfigRepository.fetchConfig() returns to override this map with the
// admin-panel-controlled data.
//
// The admin panel decides:
//   • which vehicle types are deployed at each location
//   • whether each type is subscription-included, pay-as-you-go, or both
//   • which locations are active

import 'app_config_model.dart'
    show RemoteLocationConfig, RemotePaymentModel;

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TransportMode { bike, ebike, buggy, bus }

enum TransportPaymentModel {
  /// Riding is covered by an active subscription.
  subscriptionIncluded,

  /// Always charged per trip regardless of subscription.
  payAsYouGo,

  /// Included in higher-tier plans; pay-as-you-go on lower tiers.
  both,
}

// ── Models ────────────────────────────────────────────────────────────────────

class VehicleConfig {
  final TransportMode mode;
  final TransportPaymentModel paymentModel;

  const VehicleConfig({
    required this.mode,
    required this.paymentModel,
  });
}

class CampusTransportConfig {
  final String locationName;
  final List<VehicleConfig> vehicles;

  const CampusTransportConfig({
    required this.locationName,
    required this.vehicles,
  });

  bool has(TransportMode mode) =>
      vehicles.any((v) => v.mode == mode);

  VehicleConfig? configFor(TransportMode mode) =>
      vehicles.where((v) => v.mode == mode).firstOrNull;

  TransportPaymentModel? paymentFor(TransportMode mode) =>
      configFor(mode)?.paymentModel;
}

// ── Registry ──────────────────────────────────────────────────────────────────
/// Starts with hardcoded fallback data.
/// Call [applyRemoteConfig] after fetching the admin config to override.

class TransportRegistry {
  TransportRegistry._();

  /// Runtime-mutable config map. Starts with the compile-time fallback;
  /// overwritten by [applyRemoteConfig] once /config is fetched.
  static Map<String, CampusTransportConfig> _live = Map.of(_configs);

  static const Map<String, CampusTransportConfig> _configs = {
    // ── Campuses: bikes + buggies ────────────────────────────────────────────
    'IIT Hyderabad': CampusTransportConfig(
      locationName: 'IIT Hyderabad',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.bike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.ebike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        // Buggy included in Semester plan; PAYG on basic tiers
        VehicleConfig(
          mode: TransportMode.buggy,
          paymentModel: TransportPaymentModel.both,
        ),
      ],
    ),

    'BITS Pilani': CampusTransportConfig(
      locationName: 'BITS Pilani',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.bike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.ebike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.buggy,
          paymentModel: TransportPaymentModel.both,
        ),
      ],
    ),

    'IIT Bombay': CampusTransportConfig(
      locationName: 'IIT Bombay',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.bike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.ebike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.buggy,
          paymentModel: TransportPaymentModel.both,
        ),
      ],
    ),

    // ── Buggy-only campuses (no cycles deployed) ─────────────────────────────
    'IIT Delhi': CampusTransportConfig(
      locationName: 'IIT Delhi',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.buggy,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
      ],
    ),

    'NIT Warangal': CampusTransportConfig(
      locationName: 'NIT Warangal',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.buggy,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
      ],
    ),

    // ── Campuses with buggy + bus ─────────────────────────────────────────────
    'IIT Madras': CampusTransportConfig(
      locationName: 'IIT Madras',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.buggy,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.bus,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
      ],
    ),

    // ── Corporate parks ───────────────────────────────────────────────────────
    'HITEC City': CampusTransportConfig(
      locationName: 'HITEC City',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.bike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.ebike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.buggy,
          paymentModel: TransportPaymentModel.both,
        ),
        VehicleConfig(
          mode: TransportMode.bus,
          paymentModel: TransportPaymentModel.payAsYouGo,
        ),
      ],
    ),

    'Gachibowli IT Park': CampusTransportConfig(
      locationName: 'Gachibowli IT Park',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.bike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.ebike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.buggy,
          paymentModel: TransportPaymentModel.both,
        ),
      ],
    ),

    // ── Public recreation tracks — bikes/ebikes only (no transit vehicles) ───
    'ORR Track': CampusTransportConfig(
      locationName: 'ORR Track',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.bike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.ebike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
      ],
    ),

    'Necklace Road': CampusTransportConfig(
      locationName: 'Necklace Road',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.bike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.ebike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
      ],
    ),

    'Marine Drive': CampusTransportConfig(
      locationName: 'Marine Drive',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.bike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.ebike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
      ],
    ),

    'Cubbon Park': CampusTransportConfig(
      locationName: 'Cubbon Park',
      vehicles: [
        VehicleConfig(
          mode: TransportMode.bike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
        VehicleConfig(
          mode: TransportMode.ebike,
          paymentModel: TransportPaymentModel.subscriptionIncluded,
        ),
      ],
    ),
  };

  /// Look up a location's config. Returns a bike-only fallback if not found —
  /// ensures nothing crashes while admin is setting up a new location.
  static CampusTransportConfig forLocation(String? name) =>
      _live[name] ??
      const CampusTransportConfig(
        locationName: 'Unknown',
        vehicles: [
          VehicleConfig(
            mode: TransportMode.bike,
            paymentModel: TransportPaymentModel.payAsYouGo,
          ),
        ],
      );

  static List<String> get allLocationNames => _live.keys.toList();

  // ── Remote config override ────────────────────────────────────────────────

  /// Called once by the app after [AppConfigRepository.fetchConfig] returns.
  /// Converts the server's [RemoteLocationConfig] list into the local
  /// [CampusTransportConfig] shape and replaces the live registry.
  ///
  /// Only active locations are applied; inactive ones are silently skipped.
  static void applyRemoteConfig(List<RemoteLocationConfig> locations) {
    final updated = <String, CampusTransportConfig>{};
    for (final loc in locations) {
      if (!loc.active) continue;
      final vehicles = loc.vehicles
          .where((v) => v.enabled)
          .map((v) => VehicleConfig(
                mode: _modeFromString(v.mode),
                paymentModel: _paymentFromRemote(v.paymentModel),
              ))
          .toList();
      updated[loc.name] = CampusTransportConfig(
        locationName: loc.name,
        vehicles: vehicles,
      );
    }
    if (updated.isNotEmpty) _live = updated;
  }

  static TransportMode _modeFromString(String s) {
    switch (s) {
      case 'ebike':  return TransportMode.ebike;
      case 'buggy':  return TransportMode.buggy;
      case 'bus':    return TransportMode.bus;
      default:       return TransportMode.bike;
    }
  }

  static TransportPaymentModel _paymentFromRemote(RemotePaymentModel m) {
    switch (m) {
      case RemotePaymentModel.subscriptionIncluded:
        return TransportPaymentModel.subscriptionIncluded;
      case RemotePaymentModel.payAsYouGo:
        return TransportPaymentModel.payAsYouGo;
      case RemotePaymentModel.both:
        return TransportPaymentModel.both;
    }
  }
}
