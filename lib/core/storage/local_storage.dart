import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class LocalStorage {
  static SharedPreferences? _prefs;
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // In-memory cache for auth tokens — pre-loaded during init() so that the
  // Dio interceptor can read them synchronously without async overhead.
  static String? _cachedToken;
  static String? _cachedRefreshToken;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Load auth tokens from secure storage.
    _cachedToken = await _secureStorage.read(key: _tokenKey);
    _cachedRefreshToken = await _secureStorage.read(key: _refreshTokenKey);

    // One-time migration: move tokens that were previously stored in plain
    // SharedPreferences into FlutterSecureStorage.
    if (_cachedToken == null) {
      final legacy = _prefs?.getString(_tokenKey);
      if (legacy != null) {
        _cachedToken = legacy;
        await _secureStorage.write(key: _tokenKey, value: legacy);
        await _prefs?.remove(_tokenKey);
      }
    }
    if (_cachedRefreshToken == null) {
      final legacy = _prefs?.getString(_refreshTokenKey);
      if (legacy != null) {
        _cachedRefreshToken = legacy;
        await _secureStorage.write(key: _refreshTokenKey, value: legacy);
        await _prefs?.remove(_refreshTokenKey);
      }
    }
  }

  static Future<void> setString(String key, String value) async {
    await _prefs?.setString(key, value);
  }

  static String? getString(String key) {
    return _prefs?.getString(key);
  }

  static Future<void> setBool(String key, bool value) async {
    await _prefs?.setBool(key, value);
  }

  static bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  static Future<void> setInt(String key, int value) async {
    await _prefs?.setInt(key, value);
  }

  static int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  static Future<void> setDouble(String key, double value) async {
    await _prefs?.setDouble(key, value);
  }

  static double? getDouble(String key) {
    return _prefs?.getDouble(key);
  }

  static Future<void> remove(String key) async {
    await _prefs?.remove(key);
  }

  static Future<void> clear() async {
    await _prefs?.clear();
  }

  static bool containsKey(String key) {
    return _prefs?.containsKey(key) ?? false;
  }

  // Auth token helpers — stored in FlutterSecureStorage, cached in memory.
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    await _secureStorage.write(key: _tokenKey, value: token);
  }

  /// Synchronous read — safe after [init()] has completed.
  static String? getToken() => _cachedToken;

  static Future<void> saveRefreshToken(String token) async {
    _cachedRefreshToken = token;
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  /// Synchronous read — safe after [init()] has completed.
  static String? getRefreshToken() => _cachedRefreshToken;

  static Future<void> clearAuth() async {
    _cachedToken = null;
    _cachedRefreshToken = null;
    final tasks = <Future<dynamic>>[
      _secureStorage.delete(key: _tokenKey),
      _secureStorage.delete(key: _refreshTokenKey),
    ];
    if (_prefs != null) {
      tasks.add(_prefs!.remove(_tokenKey));
      tasks.add(_prefs!.remove(_refreshTokenKey));
    }
    await Future.wait(tasks);
  }

  static bool get isLoggedIn => _cachedToken != null;

  // User profile helpers
  static const String _userTypeKey = 'user_type';
  static const String _organizationKey = 'organization';
  static const String _userIdKey = 'user_id_number';

  static Future<void> saveUserType(String type) => setString(_userTypeKey, type);
  static String? getUserType() => getString(_userTypeKey);

  static Future<void> saveOrganization(String org) => setString(_organizationKey, org);
  static String? getOrganization() => getString(_organizationKey);

  static Future<void> saveUserId(String id) => setString(_userIdKey, id);
  static String? getUserId() => getString(_userIdKey);

  // App-assigned unique user ID (server-assigned UUID, formatted as MJL-XXXXXXXX)
  static const String _appUserIdKey = 'app_user_id';
  static Future<void> saveAppUserId(String id) => setString(_appUserIdKey, id);
  static String? getAppUserId() => getString(_appUserIdKey);

  /// Generates and persists an app user ID if one does not already exist.
  /// Safe to call on every app launch.
  static Future<String> ensureAppUserId() async {
    final existing = getAppUserId();
    if (existing != null && existing.isNotEmpty) return existing;
    const uuid = Uuid();
    final raw = uuid.v4().replaceAll('-', '').substring(0, 8).toUpperCase();
    final generated = 'MJL-$raw';
    await saveAppUserId(generated);
    return generated;
  }

  static const String _campusRoleKey = 'campus_role';
  static Future<void> saveCampusRole(String role) => setString(_campusRoleKey, role);
  static String? getCampusRole() => getString(_campusRoleKey);

  // Wallet balance helpers
  static const String _walletBalanceKey = 'wallet_balance';
  static double getWalletBalance() => getDouble(_walletBalanceKey) ?? 0.0;
  static Future<void> saveWalletBalance(double balance) =>
      setDouble(_walletBalanceKey, balance);

  // ── Coin system ─────────────────────────────────────────────────────────
  // 1 coin = 1 free ride

  // Loyalty coins stored as comma-separated expiry dates (YYYY-MM-DD)
  // Each entry = 1 coin. Expired entries are purged on read.
  static const String _loyaltyCoinDatesKey = 'loyalty_coin_dates';

  static List<String> _getLoyaltyCoinDates() {
    final raw = getString(_loyaltyCoinDatesKey);
    if (raw == null || raw.isEmpty) return [];
    return raw.split(',');
  }

  static Future<void> _saveLoyaltyCoinDates(List<String> dates) =>
      setString(_loyaltyCoinDatesKey, dates.join(','));

  /// Purge expired loyalty coins (>30 days) and return valid count.
  static int getCoinBalance() {
    final dates = _getLoyaltyCoinDates();
    if (dates.isEmpty) return 0;
    final now = DateTime.now();
    final valid = dates.where((d) {
      final parsed = DateTime.tryParse(d);
      if (parsed == null) return false;
      return now.difference(parsed).inDays <= 30;
    }).toList();
    // Persist cleanup (fire-and-forget)
    if (valid.length != dates.length) {
      _saveLoyaltyCoinDates(valid);
    }
    return valid.length;
  }

  /// Add a loyalty coin with today's date (expires in 30 days).
  static Future<void> addLoyaltyCoin() async {
    final dates = _getLoyaltyCoinDates();
    dates.add(DateTime.now().toIso8601String().substring(0, 10));
    await _saveLoyaltyCoinDates(dates);
  }

  /// Use one loyalty coin (removes the oldest valid coin). Returns true if used.
  static Future<bool> useLoyaltyCoin() async {
    final now = DateTime.now();
    final dates = _getLoyaltyCoinDates();
    final valid = dates.where((d) {
      final parsed = DateTime.tryParse(d);
      if (parsed == null) return false;
      return now.difference(parsed).inDays <= 30;
    }).toList();
    if (valid.isEmpty) return false;
    valid.removeAt(0); // remove oldest
    await _saveLoyaltyCoinDates(valid);
    return true;
  }

  /// Days until the oldest loyalty coin expires. -1 if no coins.
  static int loyaltyCoinExpiryDays() {
    final dates = _getLoyaltyCoinDates();
    if (dates.isEmpty) return -1;
    final now = DateTime.now();
    int minDays = 999;
    for (final d in dates) {
      final parsed = DateTime.tryParse(d);
      if (parsed == null) continue;
      final remaining = 30 - now.difference(parsed).inDays;
      if (remaining > 0 && remaining < minDays) minDays = remaining;
    }
    return minDays == 999 ? -1 : minDays;
  }

  // Wallet-paid ride count (for loyalty bonus: 1 coin per 10 rides)
  static const String _walletRideCountKey = 'wallet_ride_count';
  static int getWalletRideCount() => getInt(_walletRideCountKey) ?? 0;
  static Future<void> saveWalletRideCount(int count) =>
      setInt(_walletRideCountKey, count);

  // Subscription coins: total allocated, redeemable/day, carry-forward cap
  static const String _subCoinsKey = 'sub_coins_remaining';
  static const String _subCoinsPerDayKey = 'sub_coins_per_day';
  static const String _subCoinCarryCapKey = 'sub_coin_carry_cap';
  static const String _subLastRedeemDateKey = 'sub_last_redeem_date';
  static const String _subCoinsRedeemedTodayKey = 'sub_coins_redeemed_today';
  static const String _subCarriedCoinsKey = 'sub_carried_coins';

  static int getSubCoinsRemaining() => getInt(_subCoinsKey) ?? 0;
  static Future<void> saveSubCoinsRemaining(int c) => setInt(_subCoinsKey, c);

  static int getSubCoinsPerDay() => getInt(_subCoinsPerDayKey) ?? 1;
  static Future<void> saveSubCoinsPerDay(int c) => setInt(_subCoinsPerDayKey, c);

  static int getSubCoinCarryCap() => getInt(_subCoinCarryCapKey) ?? 2;
  static Future<void> saveSubCoinCarryCap(int c) => setInt(_subCoinCarryCapKey, c);

  static int getSubCoinsRedeemedToday() => getInt(_subCoinsRedeemedTodayKey) ?? 0;
  static Future<void> saveSubCoinsRedeemedToday(int c) =>
      setInt(_subCoinsRedeemedTodayKey, c);

  static int getSubCarriedCoins() => getInt(_subCarriedCoinsKey) ?? 0;
  static Future<void> saveSubCarriedCoins(int c) =>
      setInt(_subCarriedCoinsKey, c);

  static String? getSubLastRedeemDate() => getString(_subLastRedeemDateKey);
  static Future<void> saveSubLastRedeemDate(String d) =>
      setString(_subLastRedeemDateKey, d);

  /// Returns how many subscription coins are available to use right now.
  /// Accounts for daily limit + carry-forward (max 2/day).
  static int getAvailableSubCoinsToday() {
    final remaining = getSubCoinsRemaining();
    if (remaining <= 0) return 0;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = getSubLastRedeemDate();

    if (lastDate != today) {
      // New day: carry forward unused from yesterday (max 2)
      final perDay = getSubCoinsPerDay();
      final redeemedYesterday = getSubCoinsRedeemedToday();
      final unusedYesterday = perDay - redeemedYesterday;
      final carried = unusedYesterday.clamp(0, getSubCoinCarryCap());
      // Don't persist yet — that happens on first actual redemption
      return (perDay + carried).clamp(0, remaining);
    }

    final perDay = getSubCoinsPerDay();
    final redeemed = getSubCoinsRedeemedToday();
    final carried = getSubCarriedCoins();
    final availableToday = (perDay + carried) - redeemed;
    return availableToday.clamp(0, remaining);
  }

  /// Redeem one subscription coin. Returns true if successful.
  static Future<bool> redeemSubCoin() async {
    final available = getAvailableSubCoinsToday();
    if (available <= 0) return false;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final lastDate = getSubLastRedeemDate();

    if (lastDate != today) {
      // Roll over: calculate carry-forward from yesterday
      final perDay = getSubCoinsPerDay();
      final redeemedYesterday = getSubCoinsRedeemedToday();
      final unusedYesterday = perDay - redeemedYesterday;
      final carried = unusedYesterday.clamp(0, getSubCoinCarryCap());
      await saveSubCarriedCoins(carried);
      await saveSubCoinsRedeemedToday(0);
      await saveSubLastRedeemDate(today);
    }

    await saveSubCoinsRedeemedToday(getSubCoinsRedeemedToday() + 1);
    await saveSubCoinsRemaining(getSubCoinsRemaining() - 1);
    return true;
  }

  /// Grant subscription coins when a plan is purchased.
  static Future<void> grantSubCoins({
    required int totalCoins,
    int coinsPerDay = 1,
    int carryForwardCap = 2,
  }) async {
    final existing = getSubCoinsRemaining();
    await saveSubCoinsRemaining(existing + totalCoins);
    await saveSubCoinsPerDay(coinsPerDay);
    await saveSubCoinCarryCap(carryForwardCap);
  }

  /// Check & award loyalty coin. Call after a wallet-paid ride.
  /// Awards 1 coin for every 10 wallet rides (expires in 30 days).
  static Future<int> recordWalletRide() async {
    final count = getWalletRideCount() + 1;
    await saveWalletRideCount(count);
    if (count % 10 == 0) {
      await addLoyaltyCoin();
      return 1; // 1 coin awarded
    }
    return 0; // no coin this time
  }

  /// Try to use a coin for a free ride. Checks loyalty coins first,
  /// then subscription coins. Returns true if a coin was used.
  static Future<bool> useCoinForRide() async {
    // Priority 1: loyalty coins (wallet-earned, expiring)
    final used = await useLoyaltyCoin();
    if (used) return true;
    // Priority 2: subscription coins (daily-limited)
    return redeemSubCoin();
  }

  /// Total coins displayed to user = loyalty + remaining sub coins
  static int getTotalDisplayCoins() {
    return getCoinBalance() + getSubCoinsRemaining();
  }

  // ── Active bike ride ──────────────────────────────────────────────────────
  // Used to detect an in-progress ride when the user navigates away and back.

  static const String _activeRideKey = 'active_ride';
  static const String _activeRideParamsKey = 'active_ride_params';
  static const String _activeRideServerIdKey = 'active_ride_server_id';

  static bool hasActiveRide() => getBool(_activeRideKey) ?? false;

  static Future<void> saveActiveRide(Map<String, dynamic> params) async {
    await setBool(_activeRideKey, true);
    await setString(_activeRideParamsKey, jsonEncode(params));
  }

  /// Persists the server-assigned ride ID returned by POST /rides/start.
  /// Used by the end-ride flow to call POST /rides/:id/end.
  static Future<void> saveActiveRideServerId(String rideId) =>
      setString(_activeRideServerIdKey, rideId);

  static String? getActiveRideServerId() => getString(_activeRideServerIdKey);

  static Map<String, dynamic> getActiveRideParams() {
    final raw = getString(_activeRideParamsKey);
    if (raw == null) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> clearActiveRide() async {
    await remove(_activeRideKey);
    await remove(_activeRideParamsKey);
    await remove(_activeRideServerIdKey);
  }

  // ── Active transit trip (bus / buggy) ─────────────────────────────────────
  // Persists the boarding details so any screen can detect an ongoing trip.

  static const String _activeTransitTripKey = 'active_transit_trip';

  static bool hasActiveTransitTrip() => getString(_activeTransitTripKey) != null;

  static Future<void> saveActiveTransitTrip(Map<String, String> data) =>
      setString(_activeTransitTripKey, jsonEncode(data));

  static Map<String, String>? getActiveTransitTrip() {
    final raw = getString(_activeTransitTripKey);
    if (raw == null) return null;
    try {
      return Map<String, String>.from(
          (jsonDecode(raw) as Map).map((k, v) => MapEntry(k.toString(), v.toString())));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearActiveTransitTrip() => remove(_activeTransitTripKey);
}
