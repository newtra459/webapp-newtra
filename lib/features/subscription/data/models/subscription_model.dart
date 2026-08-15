String _firstNonEmpty(dynamic a, dynamic b, dynamic c) {
  final sa = a as String? ?? '';
  if (sa.isNotEmpty) return sa;
  final sb = b as String? ?? '';
  if (sb.isNotEmpty) return sb;
  final sc = c as String? ?? '';
  return sc;
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final String price;
  final double priceValue;
  final String duration;
  final int durationDays;
  final int coins;
  final int dailyTimeLimitMins;
  final List<String> features;
  final String category;
  final String locationName;
  final bool popular;
  final List<String> includedModes;
  final List<String> vehicleTypes;
  final List<String> zoneIds;
  final String targetType;
  final String pricingModel;
  final double securityDeposit;
  final double discount;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.priceValue = 0,
    required this.duration,
    this.durationDays = 30,
    this.coins = 0,
    this.dailyTimeLimitMins = 0,
    this.features = const [],
    required this.category,
    required this.locationName,
    this.popular = false,
    this.includedModes = const [],
    this.vehicleTypes = const [],
    this.zoneIds = const [],
    this.targetType = 'public',
    this.pricingModel = 'subscription',
    this.securityDeposit = 0,
    this.discount = 0,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    // price comes as numeric from the new backend
    final priceNum = (json['price'] as num?)?.toDouble() ?? 0;
    final monthlyFee = (json['monthly_fee'] as num?)?.toDouble() ?? 0;
    final effectivePrice = priceNum > 0 ? priceNum : monthlyFee;
    final priceStr = effectivePrice > 0 ? '₹${effectivePrice.toStringAsFixed(0)}' : 'Free';
    final typeStr = json['type'] as String? ?? '';

    return SubscriptionPlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      price: priceStr,
      priceValue: effectivePrice,
      duration: json['duration'] as String? ?? typeStr,
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 30,
      coins: (json['coins_included'] as num?)?.toInt() ?? (json['coins'] as num?)?.toInt() ?? 0,
      dailyTimeLimitMins: (json['daily_time_limit_mins'] as num?)?.toInt() ?? 0,
      features: (json['features'] as List?)?.cast<String>() ?? [],
      category: json['category'] as String? ?? json['target_type'] as String? ?? json['bike_type'] as String? ?? '',
      locationName: _firstNonEmpty(json['location'], json['location_name'], json['station_id']),
      popular: json['popular'] as bool? ?? false,
      includedModes: (json['included_modes'] as List?)?.cast<String>() ?? [],
      vehicleTypes: (json['vehicle_types'] as List?)?.cast<String>() ?? [],
      zoneIds: (json['zone_ids'] as List?)?.cast<String>() ?? [],
      targetType: json['target_type'] as String? ?? 'public',
      pricingModel: json['pricing_model'] as String? ?? 'subscription',
      securityDeposit: (json['security_deposit'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': priceValue,
        'duration': duration,
        'duration_days': durationDays,
        'coins_included': coins,
        'daily_time_limit_mins': dailyTimeLimitMins,
        'features': features,
        'category': category,
        'location': locationName,
        'popular': popular,
        'included_modes': includedModes,
        'vehicle_types': vehicleTypes,
        'zone_ids': zoneIds,
        'target_type': targetType,
        'pricing_model': pricingModel,
      };

  double get totalCharge {
    final total = priceValue + securityDeposit - discount;
    return total < 0 ? 0 : total;
  }
}

class UserSubscription {
  final String id;
  final String planName;
  final String locationName;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;
  final int daysRemaining;
  final int coinsBalance;
  final int timeBalanceMins;
  final List<String> vehicleTypes;
  final SubscriptionPlan? plan;

  const UserSubscription({
    required this.id,
    required this.planName,
    required this.locationName,
    required this.startDate,
    required this.endDate,
    this.isActive = true,
    this.daysRemaining = 0,
    this.coinsBalance = 0,
    this.timeBalanceMins = 0,
    this.vehicleTypes = const [],
    this.plan,
  });

  /// Parse from GET /me/subscription response item (UserSubscriptionWithPlan)
  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val) ?? DateTime.now();
      }
      return DateTime.now();
    }

    // Handle the new nested format from GET /me/subscription
    final userSub = json['user_subscription'] as Map<String, dynamic>?;
    final planData = json['plan'] as Map<String, dynamic>?;

    if (userSub != null) {
      // New format: { user_subscription: {...}, plan: {...}, vehicle_types: [...], days_remaining: N }
      return UserSubscription(
        id: userSub['id'] as String? ?? '',
        planName: planData?['name'] as String? ?? userSub['subscription_id'] as String? ?? '',
        locationName: planData?['location'] as String? ?? '',
        startDate: parseDate(userSub['start_date']),
        endDate: parseDate(userSub['end_date']),
        isActive: (userSub['status'] as String?) == 'active',
        daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
        coinsBalance: (userSub['coins_balance'] as num?)?.toInt() ?? 0,
        timeBalanceMins: (userSub['time_balance_mins'] as num?)?.toInt() ?? 0,
        vehicleTypes: (json['vehicle_types'] as List?)?.cast<String>() ?? [],
        plan: planData != null ? SubscriptionPlan.fromJson(planData) : null,
      );
    }

    // Flat format (activation response or legacy)
    return UserSubscription(
      id: json['id'] as String? ?? '',
      planName: json['plan_name'] as String? ?? json['subscription_id'] as String? ?? '',
      locationName: json['location_name'] as String? ?? json['location'] as String? ?? '',
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      isActive: (json['status'] as String? ?? 'active') == 'active' || (json['is_active'] as bool? ?? true),
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ??
          parseDate(json['end_date']).difference(DateTime.now()).inDays,
      coinsBalance: (json['coins_balance'] as num?)?.toInt() ?? 0,
      timeBalanceMins: (json['time_balance_mins'] as num?)?.toInt() ?? 0,
      vehicleTypes: (json['vehicle_types'] as List?)?.cast<String>() ?? [],
    );
  }
}
