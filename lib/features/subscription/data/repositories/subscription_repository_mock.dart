// Temporary mock repository — swapped for SubscriptionRepositoryImpl
// once the backend /subscriptions endpoint is live.
// To switch back: change subscriptionRepositoryProvider in subscription_provider.dart.

import '../models/subscription_model.dart';
import 'subscription_repository.dart';

class SubscriptionRepositoryMock implements SubscriptionRepository {
  static final List<SubscriptionPlan> _plans = [
    // ── IIT Hyderabad ──────────────────────────────────────────────────────
    SubscriptionPlan(
      id: 'iith-basic-7d',
      name: 'Campus Basic',
      price: '₹49',
      priceValue: 49.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 30,
      features: ['20 min/day ride time', '30 bonus coins', 'Campus routes only'],
      category: 'campus',
      locationName: 'IIT Hyderabad',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'iith-pro-30d',
      name: 'Campus Pro',
      price: '₹149',
      priceValue: 149.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 150,
      features: ['60 min/day ride time', '150 bonus coins', 'All campus routes', 'Night rides'],
      category: 'campus',
      locationName: 'IIT Hyderabad',
      popular: true,
      includedModes: ['bike', 'ebike'],
    ),
    SubscriptionPlan(
      id: 'iith-semester-180d',
      name: 'Campus Semester',
      price: '₹399',
      priceValue: 399.0,
      duration: '180 Days',
      durationDays: 180,
      coins: 500,
      features: ['Unlimited ride time', '500 bonus coins', 'All campus routes', 'Night rides'],
      category: 'campus',
      locationName: 'IIT Hyderabad',
      includedModes: ['bike', 'ebike', 'buggy'],
    ),

    // ── BITS Pilani ────────────────────────────────────────────────────────
    SubscriptionPlan(
      id: 'bits-lite-7d',
      name: 'Campus Lite',
      price: '₹39',
      priceValue: 39.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 25,
      features: ['15 min/day ride time', '25 bonus coins', 'Campus loop only'],
      category: 'campus',
      locationName: 'BITS Pilani',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'bits-plus-30d',
      name: 'Campus Plus',
      price: '₹129',
      priceValue: 129.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 120,
      features: ['45 min/day ride time', '120 bonus coins', 'All campus routes', 'Night rides'],
      category: 'campus',
      locationName: 'BITS Pilani',
      popular: true,
      includedModes: ['bike', 'ebike'],
    ),
    SubscriptionPlan(
      id: 'bits-annual-365d',
      name: 'Campus Annual',
      price: '₹699',
      priceValue: 699.0,
      duration: '365 Days',
      durationDays: 365,
      coins: 1000,
      features: ['Unlimited ride time', '1000 bonus coins', 'All campus routes', 'Night rides', 'Guest passes'],
      category: 'campus',
      locationName: 'BITS Pilani',
      includedModes: ['bike', 'ebike', 'buggy'],
    ),

    // ── IIT Bombay ─────────────────────────────────────────────────────────
    SubscriptionPlan(
      id: 'iitb-basic-7d',
      name: 'Campus Basic',
      price: '₹59',
      priceValue: 59.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 35,
      features: ['25 min/day ride time', '35 bonus coins', 'Campus routes only'],
      category: 'campus',
      locationName: 'IIT Bombay',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'iitb-pro-30d',
      name: 'Campus Pro',
      price: '₹169',
      priceValue: 169.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 170,
      features: ['60 min/day ride time', '170 bonus coins', 'All campus routes', 'Night rides'],
      category: 'campus',
      locationName: 'IIT Bombay',
      popular: true,
      includedModes: ['bike', 'ebike'],
    ),
    SubscriptionPlan(
      id: 'iitb-semester-180d',
      name: 'Campus Semester',
      price: '₹449',
      priceValue: 449.0,
      duration: '180 Days',
      durationDays: 180,
      coins: 600,
      features: ['Unlimited ride time', '600 bonus coins', 'All campus routes', 'Night rides'],
      category: 'campus',
      locationName: 'IIT Bombay',
      includedModes: ['bike', 'ebike', 'buggy'],
    ),

    // ── IIT Madras ─────────────────────────────────────────────────────────
    SubscriptionPlan(
      id: 'iitm-basic-7d',
      name: 'Campus Basic',
      price: '₹49',
      priceValue: 49.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 30,
      features: ['20 min/day ride time', '30 bonus coins', 'Campus routes only'],
      category: 'campus',
      locationName: 'IIT Madras',
      includedModes: ['buggy'],
    ),
    SubscriptionPlan(
      id: 'iitm-pro-30d',
      name: 'Campus Pro',
      price: '₹179',
      priceValue: 179.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 180,
      features: ['60 min/day ride time', '180 bonus coins', 'All campus routes', 'Bus included'],
      category: 'campus',
      locationName: 'IIT Madras',
      popular: true,
      includedModes: ['buggy', 'bus'],
    ),

    // ── IIT Delhi ──────────────────────────────────────────────────────────
    SubscriptionPlan(
      id: 'iitd-basic-7d',
      name: 'Campus Basic',
      price: '₹49',
      priceValue: 49.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 30,
      features: ['20 min/day ride time', '30 bonus coins', 'Campus routes only'],
      category: 'campus',
      locationName: 'IIT Delhi',
      includedModes: ['buggy'],
    ),
    SubscriptionPlan(
      id: 'iitd-pro-30d',
      name: 'Campus Pro',
      price: '₹149',
      priceValue: 149.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 150,
      features: ['60 min/day ride time', '150 bonus coins', 'All campus routes'],
      category: 'campus',
      locationName: 'IIT Delhi',
      popular: true,
      includedModes: ['buggy'],
    ),

    // ── NIT Warangal ───────────────────────────────────────────────────────
    SubscriptionPlan(
      id: 'nitw-basic-7d',
      name: 'Campus Basic',
      price: '₹39',
      priceValue: 39.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 25,
      features: ['15 min/day ride time', '25 bonus coins', 'Campus routes only'],
      category: 'campus',
      locationName: 'NIT Warangal',
      includedModes: ['buggy'],
    ),
    SubscriptionPlan(
      id: 'nitw-pro-30d',
      name: 'Campus Pro',
      price: '₹129',
      priceValue: 129.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 120,
      features: ['45 min/day ride time', '120 bonus coins', 'All campus routes'],
      category: 'campus',
      locationName: 'NIT Warangal',
      popular: true,
      includedModes: ['buggy'],
    ),

    // ── HITEC City (Corporate) ─────────────────────────────────────────────
    SubscriptionPlan(
      id: 'hc-weekly-7d',
      name: 'Commuter Weekly',
      price: '₹199',
      priceValue: 199.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 50,
      features: ['45 min/day ride time', '50 bonus coins', 'IT corridor routes'],
      category: 'corporate',
      locationName: 'HITEC City',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'hc-monthly-30d',
      name: 'Commuter Monthly',
      price: '₹499',
      priceValue: 499.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 250,
      features: ['90 min/day ride time', '250 bonus coins', 'All city routes', 'Priority unlock'],
      category: 'corporate',
      locationName: 'HITEC City',
      popular: true,
      includedModes: ['bike', 'ebike'],
    ),
    SubscriptionPlan(
      id: 'hc-quarterly-90d',
      name: 'Commuter Quarterly',
      price: '₹1,199',
      priceValue: 1199.0,
      duration: '90 Days',
      durationDays: 90,
      coins: 800,
      features: ['Unlimited ride time', '800 bonus coins', 'All city routes', 'Priority unlock', 'Dedicated support'],
      category: 'corporate',
      locationName: 'HITEC City',
      includedModes: ['bike', 'ebike', 'buggy'],
    ),

    // ── Gachibowli IT Park (Corporate) ────────────────────────────────────
    SubscriptionPlan(
      id: 'gec-weekly-7d',
      name: 'Office Weekly',
      price: '₹179',
      priceValue: 179.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 40,
      features: ['30 min/day ride time', '40 bonus coins', 'Tech park routes'],
      category: 'corporate',
      locationName: 'Gachibowli IT Park',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'gec-monthly-30d',
      name: 'Office Monthly',
      price: '₹449',
      priceValue: 449.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 200,
      features: ['60 min/day ride time', '200 bonus coins', 'All city routes', 'Priority unlock'],
      category: 'corporate',
      locationName: 'Gachibowli IT Park',
      popular: true,
      includedModes: ['bike', 'ebike'],
    ),
    SubscriptionPlan(
      id: 'gec-premium-90d',
      name: 'Office Premium',
      price: '₹1,099',
      priceValue: 1099.0,
      duration: '90 Days',
      durationDays: 90,
      coins: 700,
      features: ['Unlimited ride time', '700 bonus coins', 'All city routes', 'Priority unlock', 'Dedicated support'],
      category: 'corporate',
      locationName: 'Gachibowli IT Park',
      includedModes: ['bike', 'ebike', 'buggy'],
    ),

    // ── ORR Track (Public) ─────────────────────────────────────────────────
    SubscriptionPlan(
      id: 'orr-day-1d',
      name: 'ORR Day Pass',
      price: '₹49',
      priceValue: 49.0,
      duration: '1 Day',
      durationDays: 1,
      coins: 20,
      features: ['Unlimited rides for 1 day', '20 bonus coins', 'Full ORR cycling track'],
      category: 'public',
      locationName: 'ORR Track',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'orr-weekly-7d',
      name: 'ORR Weekly',
      price: '₹149',
      priceValue: 149.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 80,
      features: ['60 min/day ride time', '80 bonus coins', 'Full ORR cycling track', 'Weekend night rides'],
      category: 'public',
      locationName: 'ORR Track',
      popular: true,
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'orr-monthly-30d',
      name: 'ORR Monthly',
      price: '₹349',
      priceValue: 349.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 250,
      features: ['Unlimited ride time', '250 bonus coins', 'Full ORR cycling track', 'Night rides', 'Fitness analytics'],
      category: 'public',
      locationName: 'ORR Track',
      includedModes: ['bike', 'ebike'],
    ),

    // ── Necklace Road (Public) ─────────────────────────────────────────────
    SubscriptionPlan(
      id: 'nr-day-1d',
      name: 'Lakeside Day Pass',
      price: '₹39',
      priceValue: 39.0,
      duration: '1 Day',
      durationDays: 1,
      coins: 15,
      features: ['Unlimited rides for 1 day', '15 bonus coins', 'Necklace Road loop'],
      category: 'public',
      locationName: 'Necklace Road',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'nr-weekly-7d',
      name: 'Lakeside Weekly',
      price: '₹129',
      priceValue: 129.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 60,
      features: ['45 min/day ride time', '60 bonus coins', 'Necklace Road loop', 'Evening rides'],
      category: 'public',
      locationName: 'Necklace Road',
      popular: true,
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'nr-monthly-30d',
      name: 'Lakeside Monthly',
      price: '₹299',
      priceValue: 299.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 200,
      features: ['Unlimited ride time', '200 bonus coins', 'Necklace Road loop', 'Night rides'],
      category: 'public',
      locationName: 'Necklace Road',
      includedModes: ['bike', 'ebike'],
    ),

    // ── Marine Drive (Public) ──────────────────────────────────────────────
    SubscriptionPlan(
      id: 'md-day-1d',
      name: 'Coastal Day Pass',
      price: '₹59',
      priceValue: 59.0,
      duration: '1 Day',
      durationDays: 1,
      coins: 25,
      features: ['Unlimited rides for 1 day', '25 bonus coins', 'Marine Drive stretch'],
      category: 'public',
      locationName: 'Marine Drive',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'md-weekly-7d',
      name: 'Coastal Weekly',
      price: '₹169',
      priceValue: 169.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 90,
      features: ['60 min/day ride time', '90 bonus coins', 'Marine Drive stretch', 'Sunrise rides'],
      category: 'public',
      locationName: 'Marine Drive',
      popular: true,
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'md-monthly-30d',
      name: 'Coastal Monthly',
      price: '₹399',
      priceValue: 399.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 300,
      features: ['Unlimited ride time', '300 bonus coins', 'Marine Drive stretch', 'Night rides', 'Fitness analytics'],
      category: 'public',
      locationName: 'Marine Drive',
      includedModes: ['bike', 'ebike'],
    ),

    // ── Cubbon Park (Public) ───────────────────────────────────────────────
    SubscriptionPlan(
      id: 'cp-day-1d',
      name: 'Park Day Pass',
      price: '₹29',
      priceValue: 29.0,
      duration: '1 Day',
      durationDays: 1,
      coins: 10,
      features: ['Unlimited rides for 1 day', '10 bonus coins', 'Cubbon Park trails'],
      category: 'public',
      locationName: 'Cubbon Park',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'cp-weekly-7d',
      name: 'Park Weekly',
      price: '₹99',
      priceValue: 99.0,
      duration: '7 Days',
      durationDays: 7,
      coins: 50,
      features: ['45 min/day ride time', '50 bonus coins', 'Cubbon Park trails', 'Morning rides'],
      category: 'public',
      locationName: 'Cubbon Park',
      popular: true,
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'cp-monthly-30d',
      name: 'Park Monthly',
      price: '₹249',
      priceValue: 249.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 150,
      features: ['Unlimited ride time', '150 bonus coins', 'Cubbon Park trails', 'Night rides'],
      category: 'public',
      locationName: 'Cubbon Park',
      includedModes: ['bike', 'ebike'],
    ),

    // ── Top-up (all locations) ─────────────────────────────────────────────
    SubscriptionPlan(
      id: 'topup-quick-1d',
      name: 'Quick Top-up',
      price: '₹29',
      priceValue: 29.0,
      duration: '1 Day',
      durationDays: 1,
      coins: 15,
      features: ['30 min single ride', '15 bonus coins'],
      category: 'topup',
      locationName: 'All Locations',
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'topup-weekend-2d',
      name: 'Weekend Pass',
      price: '₹79',
      priceValue: 79.0,
      duration: '2 Days',
      durationDays: 2,
      coins: 50,
      features: ['Unlimited weekend rides', '50 bonus coins', 'All routes'],
      category: 'topup',
      locationName: 'All Locations',
      popular: true,
      includedModes: ['bike'],
    ),
    SubscriptionPlan(
      id: 'topup-ridepack-30d',
      name: 'Ride Pack 10',
      price: '₹199',
      priceValue: 199.0,
      duration: '30 Days',
      durationDays: 30,
      coins: 100,
      features: ['10 rides (45 min each)', '100 bonus coins', 'Transferable to friends'],
      category: 'topup',
      locationName: 'All Locations',
      includedModes: ['bike'],
    ),
  ];

  @override
  Future<List<SubscriptionPlan>> getPlans({String? location, String? userType, String? organizationId}) async {
    await Future.delayed(const Duration(milliseconds: 300)); // simulate network
    if (location != null && location != 'All Locations') {
      return _plans.where((p) => p.locationName == location || p.locationName == 'All Locations').toList();
    }
    return _plans;
  }

  @override
  Future<UserSubscription> activateSubscription(String planId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final plan = _plans.firstWhere((p) => p.id == planId);
    return UserSubscription(
      id: 'mock-sub-$planId',
      planName: plan.name,
      locationName: plan.locationName,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: plan.durationDays)),
    );
  }

  @override
  Future<List<UserSubscription>> getActiveSubscriptions() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return [
      UserSubscription(
        id: 'mock-active-sub',
        planName: 'Campus Pro',
        locationName: 'IIT Hyderabad',
        startDate: DateTime(2026, 3, 1),
        endDate: DateTime(2026, 4, 1),
      ),
    ];
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  /// Mock: simulates the admin-panel ID list lookup.
  /// In production this is replaced by the backend POST /subscriptions/verify-id call.
  static const Map<String, List<String>> _mockVerifiedIds = {
    'IIT Hyderabad': ['IITH001', 'IITH002', 'IITH003', 'IITH100'],
    'IIT Bombay':    ['IITB001', 'IITB002', 'IITB050'],
    'IIT Delhi':     ['IITD001', 'IITD002'],
    'IIT Madras':    ['IITM001', 'IITM002'],
    'BITS Pilani':   ['BITS001', 'BITS002', 'BITS100'],
    'NIT Warangal':  ['NITW001', 'NITW002'],
    'TCS':           ['TCS1001', 'TCS1002', 'TCS2000'],
    'Infosys':       ['INF001', 'INF002', 'INF500'],
    'Wipro':         ['WIP001', 'WIP002'],
    'HCL':           ['HCL001', 'HCL002'],
    'Tech Mahindra': ['TM001', 'TM002'],
  };

  @override
  Future<UserSubscription?> verifyInstitutionId({
    required String org,
    required String institutionId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final validIds = _mockVerifiedIds[org];
    if (validIds == null || !validIds.contains(institutionId.trim())) {
      return null; // ID not recognised
    }
    // Find the best plan for this org (first campus/corporate plan)
    final orgPlan = _plans.firstWhere(
      (p) => p.locationName == org &&
          (p.category == 'campus' || p.category == 'corporate'),
      orElse: () => _plans.firstWhere(
        (p) => p.locationName == org,
        orElse: () => _plans.first,
      ),
    );
    return UserSubscription(
      id: 'org-sub-${institutionId.toLowerCase()}',
      planName: orgPlan.name,
      locationName: org,
      startDate: DateTime.now(),
      endDate: DateTime.now().add(Duration(days: orgPlan.durationDays)),
    );
  }
}
