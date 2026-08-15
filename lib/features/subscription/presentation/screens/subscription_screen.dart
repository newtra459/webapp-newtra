import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/config/transport_config.dart';
import '../../../../core/widgets/mj_button.dart';
import '../../../../core/storage/local_storage.dart';
import '../providers/subscription_provider.dart';
import '../../data/models/subscription_model.dart';

// ── Data models ──

enum PlanCategory { campus, corporate, public, topup }

class _Location {
  final String name;
  final String city;
  final IconData icon;
  final List<PlanCategory> availableCategories;

  const _Location({
    required this.name,
    required this.city,
    required this.icon,
    required this.availableCategories,
  });
}

class _Plan {
  final String id;
  final String name;
  final String price;
  final int priceValue;
  final String duration;
  final int durationDays;
  final int coins;
  final List<String> features;
  final Color color;
  final bool popular;
  final PlanCategory category;
  final String locationName;

  /// Transport modes included in this plan tier.
  /// Sourced from the admin panel via the plans API.
  final List<TransportMode> includedModes;

  const _Plan({
    required this.id,
    required this.name,
    required this.price,
    required this.priceValue,
    required this.duration,
    required this.durationDays,
    required this.coins,
    required this.features,
    required this.color,
    required this.category,
    required this.locationName,
    this.popular = false,
    required this.includedModes,
  });
}

// ── Plan model → UI mapping helpers ─────────────────────────────────────────
// All plan content (names, prices, features, locations) is admin-configured.
// These helpers only map API data to presentational types (Color, enum, etc.).

Color _colorForCategory(PlanCategory cat) {
  switch (cat) {
    case PlanCategory.campus:
      return AppColors.info;
    case PlanCategory.corporate:
      return AppColors.primary;
    case PlanCategory.public:
      return AppColors.primary;
    case PlanCategory.topup:
      return AppColors.speed;
  }
}

PlanCategory _planCategoryFrom(String s) {
  switch (s) {
    case 'campus':
      return PlanCategory.campus;
    case 'corporate':
      return PlanCategory.corporate;
    case 'public':
      return PlanCategory.public;
    default:
      return PlanCategory.topup;
  }
}

TransportMode? _modeFromString(String s) {
  switch (s) {
    case 'bike':
      return TransportMode.bike;
    case 'ebike':
      return TransportMode.ebike;
    case 'buggy':
      return TransportMode.buggy;
    case 'bus':
      return TransportMode.bus;
    default:
      return null;
  }
}

_Plan _planFromModel(SubscriptionPlan model) {
  final cat = _planCategoryFrom(model.category);
  return _Plan(
    id: model.id,
    name: model.name,
    price: model.price,
    priceValue: model.priceValue.toInt(),
    duration: model.duration,
    durationDays: model.durationDays,
    coins: model.coins,
    features: model.features,
    color: _colorForCategory(cat),
    popular: model.popular,
    category: cat,
    locationName: model.locationName,
    includedModes: model.includedModes
        .map(_modeFromString)
        .whereType<TransportMode>()
        .toList(),
  );
}

IconData _iconForLocation(List<PlanCategory> cats) {
  if (cats.contains(PlanCategory.campus)) return Icons.school;
  if (cats.contains(PlanCategory.corporate)) return Icons.business;
  return Icons.directions_bike;
}

// ── Screen ──

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  PlanCategory _selectedCategory = PlanCategory.topup;
  bool _tabSyncScheduled = false;
  bool _isPurchaseSheetOpen = false;
  bool _isConfirmingPurchase = false;

  // ── User profile (loaded from LocalStorage) ──
  String _userType = 'General User';
  String? _userOrg;
  String? _userId;
  bool _isIdVerified = false;

  // ── Plans and active subscription — sourced from the admin-driven API ──
  // The admin panel controls all plan content: names, prices, features,
  // locations, transport modes, etc. No plan data is hardcoded here.
  List<_Plan> _plans = const [];
  UserSubscription? _activeSub;

  // ── UI metadata: city labels per location name ─────────────────────────────
  // These are display-only strings, not business logic.
  // Admin controls which locations exist by publishing plans for them.
  static const Map<String, String> _locationCities = {
    'IIT Hyderabad': 'Sangareddy',
    'IIT Bombay': 'Mumbai',
    'IIT Delhi': 'Delhi',
    'IIT Madras': 'Chennai',
    'BITS Pilani': 'Pilani',
    'NIT Warangal': 'Warangal',
    'HITEC City': 'Hyderabad',
    'Gachibowli IT Park': 'Hyderabad',
    'ORR Track': 'Hyderabad',
    'Necklace Road': 'Hyderabad',
    'Marine Drive': 'Mumbai',
    'Cubbon Park': 'Bangalore',
  };

  // ── Company → corporate location mapping ────────────────────────────────────
  // Used to show employees only the location relevant to their company.
  static const Map<String, String> _companyLocationMap = {
    'TCS': 'HITEC City',
    'Infosys': 'HITEC City',
    'Wipro': 'Gachibowli IT Park',
    'HCL': 'Gachibowli IT Park',
    'Tech Mahindra': 'Gachibowli IT Park',
  };

  // ── Data accessors ──────────────────────────────────────────────────────────────

  /// All plans from the admin panel API (mapped to UI model).
  List<_Plan> get _allPlans => _plans;

  /// Derive unique locations from admin-published plans.
  /// The icon and category tabs are inferred from the plans at each location.
  List<_Location> get _allLocations {
    final Map<String, Set<PlanCategory>> catsByLocation = {};
    for (final p in _plans) {
      if (p.locationName == 'All Locations' || p.locationName.isEmpty) continue;
      catsByLocation.putIfAbsent(p.locationName, () => {});
      catsByLocation[p.locationName]!.add(p.category);
    }
    return catsByLocation.entries.map((e) {
      final cats = [...e.value, PlanCategory.topup];
      return _Location(
        name: e.key,
        city: _locationCities[e.key] ?? e.key,
        icon: _iconForLocation(cats),
        availableCategories: cats,
      );
    }).toList();
  }

  // ── Active subscription (from API) ─────────────────────────────────────────
  String? get _activePlanName => _activeSub?.planName;
  String? get _activePlanLocation => _activeSub?.locationName;
  DateTime get _activePlanExpiry => _activeSub?.endDate ?? DateTime.now();

  // ── Filtered locations based on user type ──────────────────────────────────
  List<_Location> get _locations {
    if (_userType == 'Student') {
      return _allLocations.where((loc) {
        if (loc.name == _userOrg) return true;
        if (loc.availableCategories.contains(PlanCategory.public)) return true;
        return false;
      }).toList();
    } else if (_userType == 'Employee') {
      final corpLoc = _companyLocationMap[_userOrg];
      return _allLocations.where((loc) {
        if (corpLoc != null && loc.name == corpLoc) return true;
        if (loc.availableCategories.contains(PlanCategory.public)) return true;
        return false;
      }).toList();
    } else {
      return _allLocations.where((loc) {
        return loc.availableCategories.contains(PlanCategory.public);
      }).toList();
    }
  }

  int _selectedLocationIndex = 0;

  _Location get _selectedLocation {
    final locs = _locations;
    if (locs.isEmpty) {
      return const _Location(
        name: '',
        city: '',
        icon: Icons.location_on,
        availableCategories: [PlanCategory.topup],
      );
    }
    final idx = _selectedLocationIndex.clamp(0, locs.length - 1);
    return locs[idx];
  }

  List<PlanCategory> get _availableTabs {
    final cats = _selectedLocation.availableCategories;
    return cats.isEmpty ? [PlanCategory.topup] : cats;
  }

  List<_Plan> get _filteredPlans {
    final availableTabs = _availableTabs;
    final category = availableTabs.contains(_selectedCategory)
        ? _selectedCategory
        : availableTabs.first;
    if (category == PlanCategory.topup) {
      final selectedLocationName = _selectedLocation.name;
      return _allPlans.where((p) {
        if (p.category != PlanCategory.topup) return false;
        if (selectedLocationName.isEmpty) return true;
        return p.locationName.isEmpty ||
            p.locationName == 'All Locations' ||
            p.locationName == selectedLocationName;
      }).toList();
    }
    final locationConfig = TransportRegistry.forLocation(
      _selectedLocation.name,
    );
    return _allPlans
        .where(
          (p) =>
              p.category == category &&
              p.locationName == _selectedLocation.name,
        )
        .where(
          (p) =>
              p.includedModes.isEmpty ||
              p.includedModes.any((m) => locationConfig.has(m)),
        )
        .toList();
  }

  CampusTransportConfig get _locationConfig =>
      TransportRegistry.forLocation(_selectedLocation.name);

  int get _daysRemaining =>
      _activePlanExpiry.difference(DateTime.now()).inDays.clamp(0, 999);

  double get _progress {
    if (_activeSub == null) return 0;
    final plan = _allPlans
        .where(
          (p) =>
              p.name == _activePlanName &&
              p.locationName == (_activePlanLocation ?? ''),
        )
        .firstOrNull;
    if (plan == null) return 0;
    return (_daysRemaining / plan.durationDays).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    // Registration saves 'University'/'Corporate'/'General' + separate campusRole.
    // Normalize to the values this screen uses ('Student'/'Employee'/'General User').
    final rawType = LocalStorage.getUserType() ?? '';
    final campusRole = LocalStorage.getCampusRole() ?? '';
    if (rawType == 'University') {
      _userType = campusRole == 'Staff' ? 'Employee' : 'Student';
    } else if (rawType == 'Corporate') {
      _userType = 'Employee';
    } else {
      _userType = 'General User';
    }
    _userOrg = LocalStorage.getOrganization();
    _userId = LocalStorage.getUserId();
    _isIdVerified = _checkIdVerification();
    // Read initial state from provider (plans may still be loading)
    final subState = ref.read(subscriptionProvider);
    _plans = subState.plans.map(_planFromModel).toList();
    _activeSub = subState.active;
    final initialTabs = _availableTabs;
    _selectedCategory = initialTabs.contains(PlanCategory.topup)
        ? PlanCategory.topup
        : initialTabs.first;
    _tabController = _createTabController();
  }

  bool _checkIdVerification() {
    // Verified if the user has a stored institution ID and an active subscription
    // allocated for their organisation (set after successful backend verification).
    if (_userId == null || _userId!.isEmpty) return false;
    if (_userOrg == null) return false;
    // Consider verified if there's an active subscription for this org.
    return _activeSub != null && _activeSub!.locationName == _userOrg;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  TabController _createTabController() {
    final tabs = _availableTabs;
    final selected = tabs.contains(_selectedCategory)
        ? _selectedCategory
        : tabs.first;
    _selectedCategory = selected;
    final controller = TabController(
      length: tabs.isEmpty ? 1 : tabs.length,
      initialIndex: tabs
          .indexOf(selected)
          .clamp(0, math.max(0, tabs.length - 1)),
      vsync: this,
    );
    controller.addListener(() {
      if (controller.indexIsChanging) return;
      final currentTabs = _availableTabs;
      if (currentTabs.isEmpty || controller.index >= currentTabs.length) return;
      final nextCategory = currentTabs[controller.index];
      if (_selectedCategory == nextCategory || !mounted) return;
      setState(() => _selectedCategory = nextCategory);
    });
    return controller;
  }

  void _syncTabs() {
    final tabs = _availableTabs;
    if (tabs.isEmpty) return;
    final nextCategory = tabs.contains(_selectedCategory)
        ? _selectedCategory
        : tabs.first;
    final nextIndex = tabs.indexOf(nextCategory);
    final needsRebuild = _tabController.length != tabs.length;
    if (!needsRebuild) {
      if (_selectedCategory != nextCategory && mounted) {
        setState(() => _selectedCategory = nextCategory);
      }
      if (_tabController.index != nextIndex) {
        _tabController.animateTo(nextIndex);
      }
      return;
    }

    final oldController = _tabController;
    _selectedCategory = nextCategory;
    _tabController = _createTabController();
    oldController.dispose();
    if (mounted) setState(() {});
  }

  void _scheduleTabSync() {
    if (_tabSyncScheduled) return;
    _tabSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tabSyncScheduled = false;
      if (mounted) _syncTabs();
    });
  }

  void _showVerificationSheet(BuildContext context, bool isDark) {
    final idCtrl = TextEditingController(text: _userId ?? '');
    String? errorMsg;
    bool verified = false;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> tryVerify() async {
            final entered = idCtrl.text.trim();
            if (entered.isEmpty) {
              setSheetState(
                () => errorMsg = 'Please enter your institution ID',
              );
              return;
            }
            setSheetState(() {
              isLoading = true;
              errorMsg = null;
            });
            // Calls POST /subscriptions/verify-id — backend checks admin-uploaded ID list.
            // If valid, backend auto-allocates the org-paid subscription.
            final sub = await ref
                .read(subscriptionProvider.notifier)
                .verifyInstitutionId(org: _userOrg!, institutionId: entered);
            if (!ctx.mounted) return;
            if (sub != null) {
              await LocalStorage.saveUserId(entered);
              setSheetState(() {
                verified = true;
                isLoading = false;
              });
              Future.delayed(const Duration(milliseconds: 900), () {
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                setState(() {
                  _userId = entered;
                  _activeSub = sub;
                  _isIdVerified = true;
                });
                _scheduleTabSync();
              });
            } else {
              setSheetState(() {
                isLoading = false;
                errorMsg =
                    'ID not recognised for $_userOrg. Please check and try again.';
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : AppColors.grey200,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.badge_outlined,
                          size: 22.w,
                          color: AppColors.warning,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Verify your institution ID',
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.white
                                    : AppColors.grey900,
                              ),
                            ),
                            Text(
                              _userOrg ?? '',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.grey500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Enter your student / employee roll number or ID to unlock exclusive plans for your institution.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isDark ? AppColors.grey400 : AppColors.grey600,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  // Input
                  TextField(
                    controller: idCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.white : AppColors.grey900,
                      letterSpacing: 1.2,
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. IITB001',
                      hintStyle: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.grey400,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.darkElevated
                          : AppColors.grey50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14.r),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 14.h,
                      ),
                      suffixIcon: verified
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.success,
                              size: 22.w,
                            )
                          : isLoading
                          ? Padding(
                              padding: EdgeInsets.all(12.w),
                              child: SizedBox(
                                width: 18.w,
                                height: 18.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : null,
                    ),
                    onSubmitted: (_) => tryVerify(),
                  ),
                  if (errorMsg != null) ...[
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 14.w,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 5.w),
                        Expanded(
                          child: Text(
                            errorMsg!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 24.h),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : AppColors.grey200,
                              ),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.grey500,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: (verified || isLoading) ? null : tryVerify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: verified
                                ? AppColors.success
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14.r),
                            ),
                            elevation: 0,
                          ),
                          child: isLoading
                              ? SizedBox(
                                  height: 18.w,
                                  width: 18.w,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      verified
                                          ? Icons.check_rounded
                                          : Icons.verified_outlined,
                                      size: 17.w,
                                    ),
                                    SizedBox(width: 7.w),
                                    Text(
                                      verified ? 'Verified!' : 'Verify ID',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    await ref.read(subscriptionProvider.notifier).loadSubscription();
  }

  void _showLocationPicker() {
    final selectedIndex =
        _selectedLocationIndex.clamp(0, math.max(0, _locations.length - 1))
            as int;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _LocationPickerSheet(
        locations: _locations,
        selectedIndex: selectedIndex,
        onSelect: (i) {
          if (i != _selectedLocationIndex) {
            setState(() => _selectedLocationIndex = i);
            _scheduleTabSync();
          }
        },
      ),
    );
  }

  Future<void> _showPurchaseConfirmation(_Plan plan) async {
    if (_isPurchaseSheetOpen || _isConfirmingPurchase) return;
    setState(() => _isPurchaseSheetOpen = true);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PurchaseSheet(
        plan: plan,
        walletBalance: LocalStorage.getWalletBalance(),
        onConfirm: (payWithWallet) => _confirmPurchase(plan, payWithWallet),
      ),
    );
    if (!mounted) return;
    setState(() => _isPurchaseSheetOpen = false);
  }

  Future<void> _confirmPurchase(_Plan plan, bool payWithWallet) async {
    if (_isConfirmingPurchase) return;
    setState(() => _isConfirmingPurchase = true);
    try {
      final subscribed = await ref
          .read(subscriptionProvider.notifier)
          .subscribe(plan.id);
      if (!subscribed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Subscription purchase failed. Check wallet balance and try again.',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
          );
        }
        return;
      }

      final newBalance = LocalStorage.getWalletBalance() - plan.priceValue;
      await LocalStorage.saveWalletBalance(newBalance);

      // Grant subscription coins (1 coin = 1 ride, redeemable daily)
      if (plan.coins > 0) {
        await LocalStorage.grantSubCoins(
          totalCoins: plan.coins,
          coinsPerDay: 1,
          carryForwardCap: 2,
        );
      }

      await ref.read(subscriptionProvider.notifier).loadSubscription();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Subscribed to ${plan.name}! ₹${plan.priceValue} deducted.${plan.coins > 0 ? ' +${plan.coins} coins added!' : ''}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isConfirmingPurchase = false);
      }
    }
  }

  // ───────────────────────────────────────────── build ──

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync provider state into local cache — ref.watch triggers rebuild on change
    final subState = ref.watch(subscriptionProvider);
    _plans = subState.plans.map(_planFromModel).toList();
    _activeSub = subState.active;

    final visibleSelectedLocationIndex = _selectedLocationIndex.clamp(
      0,
      math.max(0, _locations.length - 1),
    );
    final availableTabs = _availableTabs;
    final needsTabSync =
        availableTabs.isNotEmpty &&
        (_tabController.length != availableTabs.length ||
            !availableTabs.contains(_selectedCategory) ||
            _tabController.index >= availableTabs.length);
    if (needsTabSync) {
      _scheduleTabSync();
    }

    final plans = _filteredPlans;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFF4F6F9),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero header ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: _HeroHeader(
                activePlanName: _activePlanName,
                activePlanLocation: _activePlanLocation,
                activePlanExpiry: _activePlanExpiry,
                daysRemaining: _daysRemaining,
                progress: _progress,
                allPlans: _allPlans,
                isDark: isDark,
              ),
            ),

            // ── Body padding wrapper ─────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 40.h),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Location chips ──
                  SizedBox(
                    height: 36.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _locations.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(width: 8.w),
                      itemBuilder: (_, i) {
                        final loc = _locations[i];
                        final selected = i == visibleSelectedLocationIndex;
                        return GestureDetector(
                          onTap: () {
                            if (i != _selectedLocationIndex) {
                              setState(() => _selectedLocationIndex = i);
                              _scheduleTabSync();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : (isDark
                                        ? const Color(0xFF1E2530)
                                        : Colors.white),
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : (isDark
                                          ? Colors.white12
                                          : AppColors.grey200),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  loc.icon,
                                  size: 13.w,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.grey500,
                                ),
                                SizedBox(width: 5.w),
                                Text(
                                  loc.name,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : AppColors.grey600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 6.h),

                  // Location detail row
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13.w,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          '${_selectedLocation.name} · ${_selectedLocation.city}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.grey500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: _showLocationPicker,
                        child: Text(
                          'All locations',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // ── Verification banner ──
                  if (_userType != 'General User' && _userOrg != null) ...[
                    _VerificationBanner(
                      org: _userOrg!,
                      isVerified: _isIdVerified,
                      onTap: _isIdVerified
                          ? null
                          : () => _showVerificationSheet(context, isDark),
                    ),
                    SizedBox(height: 16.h),
                  ],

                  // ── Category tabs ──
                  _PillTabBar(
                    controller: _tabController,
                    tabs: availableTabs,
                    isDark: isDark,
                  ),
                  SizedBox(height: 20.h),

                  // ── Plan cards ──
                  ...plans.map(
                    (plan) => _PlanCard(
                      plan: plan,
                      locationConfig: _locationConfig,
                      isActive:
                          plan.name == _activePlanName &&
                          (plan.locationName == _activePlanLocation ||
                              plan.locationName == 'All Locations'),
                      onSubscribe: () => _showPurchaseConfirmation(plan),
                      isBusy: _isPurchaseSheetOpen || _isConfirmingPurchase,
                      isDark: isDark,
                    ),
                  ),

                  if (plans.isEmpty) _NoPlansIllustration(isDark: isDark),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Hero Header
// ═══════════════════════════════════════════════════════════════════

class _HeroHeader extends StatelessWidget {
  final String? activePlanName;
  final String? activePlanLocation;
  final DateTime activePlanExpiry;
  final int daysRemaining;
  final double progress;
  final List<_Plan> allPlans;
  final bool isDark;

  const _HeroHeader({
    required this.activePlanName,
    required this.activePlanLocation,
    required this.activePlanExpiry,
    required this.daysRemaining,
    required this.progress,
    required this.allPlans,
    required this.isDark,
  });

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final plan = activePlanName != null
        ? (allPlans
                  .where(
                    (p) =>
                        p.name == activePlanName &&
                        p.locationName == (activePlanLocation ?? ''),
                  )
                  .firstOrNull ??
              allPlans.where((p) => p.name == activePlanName).firstOrNull)
        : null;
    final accentColor = plan?.color ?? AppColors.primary;
    final isExpired = daysRemaining <= 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0D1412),
            Color.lerp(const Color(0xFF0D1412), accentColor, 0.18)!,
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button + title row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16.w,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'My Subscriptions',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              if (activePlanName != null) ...[
                // ── Active plan display ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: isExpired
                                  ? Colors.red.withValues(alpha: 0.2)
                                  : AppColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              isExpired ? 'EXPIRED' : 'ACTIVE',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: isExpired
                                    ? Colors.redAccent
                                    : AppColors.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              activePlanName!,
                              style: TextStyle(
                                fontSize: 26.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 13.w,
                                color: Colors.white38,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                activePlanLocation ?? '',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            isExpired
                                ? 'Expired ${_formatDate(activePlanExpiry)}'
                                : 'Renews ${_formatDate(activePlanExpiry)}',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Circular progress ring
                    SizedBox(
                      width: 72.w,
                      height: 72.w,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(72.w, 72.w),
                            painter: _RingPainter(
                              progress: progress,
                              color: accentColor,
                              trackColor: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  isExpired ? '0' : '$daysRemaining',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              Text(
                                'days',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),

                // Stat chips
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    if (plan != null) ...[
                      _StatChip(
                        icon: Icons.stars_rounded,
                        label: '${plan.coins} coins',
                        color: AppColors.warning,
                      ),
                      _StatChip(
                        icon: Icons.schedule,
                        label: plan.duration,
                        color: Colors.white54,
                      ),
                    ],
                  ],
                ),
              ] else ...[
                // ── No active plan state ──
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.card_membership_outlined,
                          color: AppColors.primary,
                          size: 24.w,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No active plan',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Pick a plan below to get started',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Ring painter
// ═══════════════════════════════════════════════════════════════════

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = math.min(cx, cy) - 4;
    final strokeWidth = 5.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final arcPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(Offset(cx, cy), radius, trackPaint);
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ═══════════════════════════════════════════════════════════════════
//  Stat chip (used in hero)
// ═══════════════════════════════════════════════════════════════════

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.w, color: color),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  No Plans Illustration
// ═══════════════════════════════════════════════════════════════════

class _NoPlansIllustration extends StatelessWidget {
  final bool isDark;
  const _NoPlansIllustration({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 20.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_membership_outlined,
              size: 38.w,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'No plans here yet',
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? AppColors.white : AppColors.grey900,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Plans for this location will appear\nonce the admin publishes them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              color: AppColors.grey500,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Verification Banner
// ═══════════════════════════════════════════════════════════════════

class _VerificationBanner extends StatelessWidget {
  final String org;
  final bool isVerified;
  final VoidCallback? onTap;

  const _VerificationBanner({
    required this.org,
    required this.isVerified,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isVerified ? AppColors.success : AppColors.warning;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(
              isVerified ? Icons.verified_rounded : Icons.info_outline_rounded,
              color: color,
              size: 17.w,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                isVerified
                    ? '$org · ID verified — exclusive plans unlocked'
                    : '$org · ID verification pending — tap to verify',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!isVerified) ...[
              SizedBox(width: 6.w),
              Icon(Icons.chevron_right_rounded, color: color, size: 16.w),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Pill Tab Bar
// ═══════════════════════════════════════════════════════════════════

class _PillTabBar extends StatelessWidget {
  final TabController controller;
  final List<PlanCategory> tabs;
  final bool isDark;

  const _PillTabBar({
    required this.controller,
    required this.tabs,
    required this.isDark,
  });

  String _label(PlanCategory cat) {
    switch (cat) {
      case PlanCategory.campus:
        return 'Campus';
      case PlanCategory.corporate:
        return 'Corporate';
      case PlanCategory.public:
        return 'Public';
      case PlanCategory.topup:
        return 'Top-up';
    }
  }

  IconData _icon(PlanCategory cat) {
    switch (cat) {
      case PlanCategory.campus:
        return Icons.school_outlined;
      case PlanCategory.corporate:
        return Icons.business_outlined;
      case PlanCategory.public:
        return Icons.park_outlined;
      case PlanCategory.topup:
        return Icons.bolt_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2030) : Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryLight],
          ),
          borderRadius: BorderRadius.circular(10.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.grey500,
        dividerHeight: 0,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: tabs
            .map(
              (cat) => Tab(
                height: 38.h,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_icon(cat), size: 14.w),
                    SizedBox(width: 5.w),
                    Text(
                      _label(cat),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Plan Card
// ═══════════════════════════════════════════════════════════════════

class _PlanCard extends StatelessWidget {
  final _Plan plan;
  final CampusTransportConfig locationConfig;
  final bool isActive;
  final VoidCallback onSubscribe;
  final bool isBusy;
  final bool isDark;

  const _PlanCard({
    required this.plan,
    required this.locationConfig,
    required this.isActive,
    required this.onSubscribe,
    required this.isBusy,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final paygModes = locationConfig.vehicles
        .where(
          (v) =>
              v.paymentModel == TransportPaymentModel.payAsYouGo &&
              !plan.includedModes.contains(v.mode),
        )
        .map((v) => v.mode)
        .toList();

    final cardBg = isDark ? const Color(0xFF161C26) : Colors.white;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: plan.popular
              ? plan.color.withValues(alpha: 0.5)
              : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.transparent),
          width: plan.popular ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: plan.popular
                ? plan.color.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: plan.popular ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Popular banner ──
          if (plan.popular)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 7.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [plan.color, plan.color.withValues(alpha: 0.8)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(19.r)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 13.w,
                    color: Colors.white,
                  ),
                  SizedBox(width: 5.w),
                  Text(
                    'MOST POPULAR',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header row: name + price ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: plan.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        _categoryIcon(plan.category),
                        color: plan.color,
                        size: 20.w,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.name,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.grey900,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            plan.duration,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.grey500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Price block
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          plan.price,
                          style: TextStyle(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w800,
                            color: plan.color,
                            height: 1,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.stars_rounded,
                              size: 12.w,
                              color: AppColors.warning,
                            ),
                            SizedBox(width: 3.w),
                            Text(
                              '+${plan.coins}',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.grey400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                // ── Divider ──
                Container(
                  height: 1,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.grey100,
                ),
                SizedBox(height: 14.h),

                // ── Features ──
                ...plan.features.map(
                  (f) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Row(
                      children: [
                        Container(
                          width: 18.w,
                          height: 18.w,
                          decoration: BoxDecoration(
                            color: plan.color.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            size: 11.w,
                            color: plan.color,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            f,
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: isDark
                                  ? Colors.white70
                                  : AppColors.grey700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Transport modes ──
                if (plan.includedModes.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : AppColors.grey50,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Included transport',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.grey500,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Wrap(
                          spacing: 6.w,
                          runSpacing: 6.h,
                          children: [
                            ...plan.includedModes.map(
                              (m) => _TransportChip(
                                mode: m,
                                isPayg: false,
                                color: plan.color,
                              ),
                            ),
                            ...paygModes.map(
                              (m) => _TransportChip(
                                mode: m,
                                isPayg: true,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 14.h),
                ] else
                  SizedBox(height: 6.h),

                // ── CTA button ──
                if (isActive)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 16.w,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          'Current Plan',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  MjButton(
                    text: 'Get ${plan.name}',
                    onPressed: isBusy ? null : onSubscribe,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _categoryIcon(PlanCategory cat) {
    switch (cat) {
      case PlanCategory.campus:
        return Icons.school_outlined;
      case PlanCategory.corporate:
        return Icons.business_center_outlined;
      case PlanCategory.public:
        return Icons.park_outlined;
      case PlanCategory.topup:
        return Icons.bolt_rounded;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Transport Chip
// ═══════════════════════════════════════════════════════════════════

class _TransportChip extends StatelessWidget {
  final TransportMode mode;
  final bool isPayg;
  final Color color;

  const _TransportChip({
    required this.mode,
    required this.isPayg,
    required this.color,
  });

  IconData get _icon {
    switch (mode) {
      case TransportMode.bike:
        return Icons.pedal_bike_outlined;
      case TransportMode.ebike:
        return Icons.electric_bike_outlined;
      case TransportMode.buggy:
        return Icons.electric_car_outlined;
      case TransportMode.bus:
        return Icons.directions_bus_outlined;
    }
  }

  String get _label {
    switch (mode) {
      case TransportMode.bike:
        return 'Bike';
      case TransportMode.ebike:
        return 'E-Bike';
      case TransportMode.buggy:
        return 'Buggy';
      case TransportMode.bus:
        return 'Bus';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 12.w, color: color),
          SizedBox(width: 4.w),
          Text(
            _label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (isPayg) ...[
            SizedBox(width: 3.w),
            Text(
              '· PAYG',
              style: TextStyle(
                fontSize: 9.sp,
                color: color.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Location Picker Bottom Sheet
// ═══════════════════════════════════════════════════════════════════

class _LocationPickerSheet extends StatelessWidget {
  final List<_Location> locations;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _LocationPickerSheet({
    required this.locations,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161C26) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 12.h),
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Row(
              children: [
                Text(
                  'Select Location',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  '${locations.length} locations',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.grey500),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Text(
              'Plans and pricing vary by location',
              style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
            ),
          ),
          SizedBox(height: 16.h),
          ...List.generate(locations.length, (i) {
            final loc = locations[i];
            final selected = i == selectedIndex;
            return ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 20.w,
                vertical: 2.h,
              ),
              leading: Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.grey100),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  loc.icon,
                  color: selected ? AppColors.primary : AppColors.grey500,
                  size: 20.w,
                ),
              ),
              title: Text(
                loc.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                  color: selected ? AppColors.primary : null,
                ),
              ),
              subtitle: Text(
                loc.city,
                style: TextStyle(fontSize: 12.sp, color: AppColors.grey500),
              ),
              trailing: selected
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: AppColors.primary,
                      size: 22.w,
                    )
                  : Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.grey300,
                      size: 20.w,
                    ),
              onTap: () {
                Navigator.pop(context);
                onSelect(i);
              },
            );
          }),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Purchase Sheet
// ═══════════════════════════════════════════════════════════════════

class _PurchaseSheet extends StatefulWidget {
  final _Plan plan;
  final double walletBalance;
  final void Function(bool payWithWallet) onConfirm;

  const _PurchaseSheet({
    required this.plan,
    required this.walletBalance,
    required this.onConfirm,
  });

  @override
  State<_PurchaseSheet> createState() => _PurchaseSheetState();
}

class _PurchaseSheetState extends State<_PurchaseSheet> {
  bool _useWallet = true;

  _Plan get plan => widget.plan;

  bool get _hasSufficientBalance => widget.walletBalance >= plan.priceValue;

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10.w),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: bold ? 17.sp : 13.sp,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: valueColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161C26) : Colors.white;
    final afterBalance = widget.walletBalance - plan.priceValue;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.grey300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 24.h),

          // Icon + title
          Container(
            width: 56.w,
            height: 56.w,
            decoration: BoxDecoration(
              color: plan.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_membership_rounded,
              color: plan.color,
              size: 28.w,
            ),
          ),
          SizedBox(height: 14.h),
          Text(
            plan.name,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4.h),
          Text(
            plan.duration,
            style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
          ),
          SizedBox(height: 20.h),

          // Summary box
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: plan.color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(color: plan.color.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                _row(context, 'Location', plan.locationName),
                _row(context, 'Duration', plan.duration),
                _row(context, 'Bonus Coins', '+${plan.coins} coins'),
                Divider(
                  height: 20.h,
                  color: plan.color.withValues(alpha: 0.15),
                ),
                _row(
                  context,
                  'Total',
                  plan.price,
                  bold: true,
                  valueColor: plan.color,
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // ── Payment method ──────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.grey50,
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: isDark ? Colors.white12 : AppColors.grey200,
              ),
            ),
            child: Column(
              children: [
                // Wallet option
                GestureDetector(
                  onTap: () {
                    if (_hasSufficientBalance) {
                      HapticFeedback.selectionClick();
                      setState(() => _useWallet = true);
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      color: _useWallet
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14.r),
                      border: _useWallet
                          ? Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: AppColors.primary,
                            size: 18.w,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pay with Wallet',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: _hasSufficientBalance
                                      ? (isDark
                                            ? Colors.white
                                            : AppColors.grey900)
                                      : AppColors.grey400,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Row(
                                children: [
                                  Text(
                                    'Balance: ₹${widget.walletBalance.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: _hasSufficientBalance
                                          ? AppColors.success
                                          : AppColors.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (!_hasSufficientBalance) ...[
                                    SizedBox(width: 6.w),
                                    Text(
                                      '· Insufficient',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                  if (_hasSufficientBalance && _useWallet) ...[
                                    SizedBox(width: 6.w),
                                    Text(
                                      '₹${afterBalance.toStringAsFixed(2)} after',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        color: AppColors.grey500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (_useWallet)
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                            size: 20.w,
                          )
                        else
                          Icon(
                            Icons.radio_button_unchecked_rounded,
                            color: AppColors.grey400,
                            size: 20.w,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // Buttons
          Row(
            children: [
              Expanded(
                child: MjButton(
                  text: 'Cancel',
                  isOutlined: true,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: MjButton(
                  text: 'Pay from Wallet',
                  onPressed: _hasSufficientBalance
                      ? () {
                          Navigator.pop(context);
                          widget.onConfirm(true);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
