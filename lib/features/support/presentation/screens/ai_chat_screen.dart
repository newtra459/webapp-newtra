import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../wallet/presentation/providers/wallet_provider.dart';
import '../../../activity/presentation/providers/activity_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../trips/presentation/providers/trips_provider.dart';
import '../../../subscription/presentation/providers/subscription_provider.dart';
import '../providers/support_provider.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _Msg {
  final String text;
  final bool isUser;
  final DateTime time;
  _Msg({required this.text, required this.isUser}) : time = DateTime.now();
}

// ── AI knowledge base ─────────────────────────────────────────────────────────

const _kb = [
  (
    ['rent', 'rent a bike', 'unlock', 'how to rent', 'start ride'],
    'To rent a bike, scan the QR code on any available bike at a station. The ride starts automatically once unlocked. Make sure you have sufficient wallet balance!',
  ),
  (
    ['vehicles', 'types', 'ebike', 'e-bike', 'buggy', 'available', 'bus'],
    'We offer four types of vehicles:\n• Regular bikes — great for short hops\n• E-bikes — powered assist for longer rides\n• Buggies — shared campus shuttles\n• Buses — public transport integration\nAvailability depends on your location and station.',
  ),
  (
    ['end', 'stop', 'end ride', 'finish', 'park'],
    'To end a ride, park the vehicle at any station and tap "End Ride" in the app. Make sure you\'re at a valid station or you may still be charged.',
  ),
  (
    [
      'payment',
      'pay',
      'upi',
      'card',
      'wallet',
      'method',
      'top up',
      'add money',
    ],
    'We support the following payment methods:\n• Credit / Debit cards\n• UPI (Google Pay, PhonePe, etc.)\n• In-app wallet balance\nYou can top up your wallet anytime from the Wallet screen.',
  ),
  (
    [
      'subscription',
      'plan',
      'subscribe',
      'cancel',
      'discount',
      'plans',
      'monthly',
      'weekly',
    ],
    'Subscriptions give you discounted ride rates and bonus coins. You can:\n• Choose Campus, Corporate, or Public location plans\n• Select Weekly, Monthly, or Annual durations\n• Get bonus coins with every plan\n• Cancel anytime from Profile > Subscriptions\n• Upgrade or downgrade whenever you like',
  ),
  (
    ['coin', 'coins', 'free ride', 'loyalty', 'bonus'],
    'Coins give you free or discounted rides! There are two types:\n\nLoyalty Coins:\n• Earn 1 coin for every 10 wallet-paid rides\n• Expire after 30 days\n• Use anytime\n\nSubscription Coins:\n• Come with your subscription plan\n• Use 1 per day (60 min ride)\n• Unused coins carry forward (max 2/day)\n• Check your wallet to see available coins!',
  ),
  (
    ['daily time', 'ride time', 'minutes', 'allocated', 'how long'],
    'With an active subscription, you get daily ride time:\n• Each coin = 60 minutes of ride time\n• Default: 1 coin/day redeemable\n• Unused coins carry forward (max 2 extra/day)\n• View your Daily Time in the Wallet screen',
  ),
  (
    ['wallet', 'balance', 'money', 'withdraw', 'refund'],
    'Your Wallet shows:\n• Available Balance — for paying rides\n• Total Coins — all earned + subscription coins\n• Redeemable Coins — coins you can use today\n• Daily Time — ride minutes available today\n\nYou can add money, withdraw, or view transaction history from the Wallet screen.',
  ),
  (
    ['qr', 'qr code', 'scan', 'not scanning', 'camera'],
    'If the QR code isn\'t scanning:\n1. Clean your camera lens\n2. Hold the phone steady at 20-30 cm\n3. Try manual entry of the bike code\n4. If it still fails, report via Support > Report Issue',
  ),
  (
    ['unlock', 'won\'t unlock', 'not unlocking', 'bike stuck'],
    'If the bike won\'t unlock:\n1. Check your internet connection\n2. Wait 10 seconds and retry\n3. Make sure your wallet has enough balance\n4. If the issue persists, tap Report Issue and we\'ll help right away!',
  ),
  (
    ['transit', 'board', 'boarding', 'buggy stop', 'bus stop'],
    'To use Transit (buggies/buses):\n1. Go to the Transit tab in the app\n2. Find your nearest stop\n3. Tap "Board" when the vehicle arrives\n4. Scan the QR code on the vehicle\n5. Tap "End Trip" when you get off\n\nMost transit rides are covered by your subscription!',
  ),
  (
    ['co2', 'environment', 'carbon', 'green', 'eco', 'emissions'],
    'Every ride you take saves CO2 compared to a car trip! You can track your total CO2 savings on the Activity screen. Join eco-focused groups to compete and maximize your environmental impact.',
  ),
  (
    ['activity', 'dashboard', 'stats', 'analytics', 'performance'],
    'The Activity Dashboard shows your riding stats:\n• Distance covered (daily, weekly, monthly, yearly)\n• Speed performance and elevation climbed\n• CO2 saved and calories burned\n• Personal records and trends\n\nAccess it from Profile > Activity Dashboard.',
  ),
  (
    ['achievement', 'achievements', 'badge', 'badges', 'unlock'],
    'Achievements are milestones you unlock by riding:\n• First Ride, Speed Demon, Century Rider\n• Green Champion, Social Butterfly\n• 30-Day Streak, Leaderboard King\n\nView all achievements in Profile > Achievements. Each shows your progress!',
  ),
  (
    ['group', 'groups', 'community', 'join group', 'create group'],
    'Groups let you connect with other riders:\n• Join or create groups (Campus, Eco, Racing, etc.)\n• Compete on group leaderboards\n• Share ride posts and achievements\n• Track collective stats (distance, CO2)\n• Make groups public or private\n\nExplore groups from the Groups tab!',
  ),
  (
    ['leaderboard', 'rank', 'ranking', 'points', 'top rider'],
    'The Leaderboard tracks top riders by:\n• Distance — most km covered\n• Points — activity score\n• CO2 Saved — environmental impact\n\nSwitch between Individual and Groups tabs to see different rankings. Keep riding to climb!',
  ),
  (
    ['friend', 'friends', 'add friend', 'follow'],
    'Connect with other riders:\n• Add friends from the Friends screen\n• View their profiles and stats\n• See their recent rides and achievements\n• Compete on leaderboards together\n\nBuild your riding community!',
  ),
  (
    ['trip', 'history', 'past rides', 'my trips', 'route'],
    'All your past rides are saved in the Trips section:\n• View trip history by date\n• See full route on the map\n• Check distance, duration, speed, calories\n• CO2 saved and elevation details\n• Payment info and coins earned\n\nReview any trip by tapping on it!',
  ),
  (
    ['profile', 'edit profile', 'account', 'personal info'],
    'Manage your profile:\n• Edit personal details (name, bio, etc.)\n• Update height, weight for accurate analytics\n• View your stats and activity strip\n• Access wallet, trips, subscriptions\n• See achievements and XP level\n\nGo to Profile > Edit Profile to update.',
  ),
  (
    ['delete', 'delete account', 'remove account', 'close account'],
    'To delete your account:\n1. Go to Profile > Settings\n2. Tap "Delete Account"\n3. Verify with OTP\n4. Confirm deletion\n\nWarning: This action is permanent and deletes all your data, including trips, achievements, and wallet balance. Make sure to withdraw any funds first!',
  ),
  (
    ['report', 'issue', 'problem', 'broken', 'damaged', 'help'],
    'You can report any issue via Support > Report Issue:\n• Broken or damaged vehicles\n• Station problems\n• Payment issues\n• App bugs\n\nDescribe the problem and we\'ll look into it within 24 hours. For urgent issues, call our helpline at 1800-XXX-XXXX.',
  ),
  (
    ['price', 'pricing', 'cost', 'how much', 'rate', 'fare'],
    'Ride pricing varies by vehicle type and subscription:\n• Base fare + per-minute charges\n• Subscribers get heavily discounted rates\n• Use coins for free rides\n• Check the pricing before starting a ride\n\nSubscriptions offer the best value!',
  ),
  (
    ['cancel', 'cancel ride', 'cancellation'],
    'To cancel a ride:\n• You can cancel before unlocking\n• After unlocking, a small cancellation fee may apply\n• Always park properly at a station before ending\n\nCancellation fees help maintain service quality.',
  ),
  (
    ['station', 'stations', 'find station', 'nearest', 'dock'],
    'Find stations on the Home map:\n• Shows distance and walk time\n• See available bikes, e-bikes, and docks\n• Filter by vehicle type\n• Navigate to any station\n\nStations are marked with green pins on the map.',
  ),
  (
    ['xp', 'experience', 'points', 'level', 'level up'],
    'Earn XP by:\n• Completing rides\n• Achieving milestones\n• Using transit\n• Daily streaks\n\nLevel up to unlock achievements and badges! Your XP and level are shown on your profile.',
  ),
  (
    ['hello', 'hi', 'hey', 'hola', 'sup'],
    'Hey there! I\'m Thor, your Newtra support bot. Ask me anything about renting bikes, payments, subscriptions, coins, transit, achievements, or troubleshooting — I\'m here to help!',
  ),
  (
    ['thank', 'thanks', 'thank you', 'thx', 'ty'],
    'Happy to help! Is there anything else you\'d like to know?',
  ),
  (
    ['bye', 'goodbye', 'see you', 'done'],
    'Take care and happy riding! Feel free to come back anytime you have questions.',
  ),
];

const _fallbacks = [
  "I'm not sure about that one. Could you rephrase? Or try one of the suggested questions below!",
  "Hmm, I didn't quite get that. Try asking about renting, payments, or troubleshooting!",
  "I'm still learning! For complex issues, tap Report Issue and our team will help you directly.",
];

String _getBotReply(String input) {
  final lower = input.toLowerCase().trim();
  for (final (keywords, reply) in _kb) {
    if (keywords.any((k) => lower.contains(k))) return reply;
  }
  return _fallbacks[Random().nextInt(_fallbacks.length)];
}

const _suggestions = [
  'What is my wallet balance?',
  'How many trips have I done?',
  'What is my last ride?',
  'Show my stats',
  'What is my subscription?',
  'How much CO2 have I saved?',
  'How do I rent a bike?',
  'What are coins?',
];

// ── Suggestion chips ─────────────────────────────────────────────────────────

// ── Screen ───────────────────────────────────────────────────────────────────

class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen>
    with TickerProviderStateMixin {
  final List<_Msg> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _isTyping = false;
  late AnimationController _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    // Welcome message
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _messages.add(
          _Msg(
            text:
                "Hey there! I'm Thor, your Newtra support bot.\n\nAsk me anything about renting bikes, transit, coins, subscriptions, achievements, groups, or troubleshooting!",
            isUser: false,
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _dotAnim.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  // ── Personalized reply using real app data ─────────────────────────────────

  Future<String> _getReply(String input) async {
    final lower = input.toLowerCase().trim();

    // ── Personalized data queries ─────────────────────────────────────────
    final walletState = ref.read(walletProvider);
    final activityState = ref.read(activityProvider);
    final profileState = ref.read(profileProvider).valueOrNull;
    final tripsState = ref.read(tripsProvider);
    final subState = ref.read(subscriptionProvider);

    final name = profileState?.firstName ?? 'Rider';
    final balance = walletState.balance;
    final trips = tripsState.trips;
    final summary = activityState.summary;
    final activeSub = subState.active;

    // Balance / wallet
    if (lower.contains('balance') ||
        lower.contains('how much') && lower.contains('wallet')) {
      return 'Hi $name! Your current wallet balance is ₹${balance.toStringAsFixed(2)}. '
          'You can top up anytime from the Wallet screen.';
    }

    // Trips / history
    if (lower.contains('how many trips') ||
        lower.contains('how many rides') ||
        lower.contains('trip count') ||
        lower.contains('total trips')) {
      return 'You\'ve completed ${summary.totalTrips} trips so far, covering '
          '${summary.totalDistance.toStringAsFixed(1)} km in total. Keep going, $name!';
    }

    // Recent trip
    if (lower.contains('last ride') ||
        lower.contains('recent trip') ||
        lower.contains('latest ride')) {
      if (trips.isNotEmpty) {
        final t = trips.first;
        return 'Your most recent trip was on ${t.date} — '
            '${t.from} → ${t.to} (${t.distance}, ${t.duration}). '
            'You earned ${t.coins} coins on that ride!';
      }
      return 'I don\'t see any recent trips yet, $name. Start your first ride from the Home screen!';
    }

    // Distance
    if (lower.contains('distance') ||
        lower.contains('km') ||
        lower.contains('kilometers')) {
      return 'You\'ve covered a total of ${summary.totalDistance.toStringAsFixed(1)} km, '
          'burned ${summary.totalCalories.toInt()} calories, '
          'and saved ${summary.totalCo2.toStringAsFixed(1)} kg of CO₂ along the way!';
    }

    // CO2 / eco
    if (lower.contains('co2') ||
        lower.contains('carbon') ||
        lower.contains('eco') ||
        lower.contains('environment')) {
      return 'Great news, $name! You\'ve saved ${summary.totalCo2.toStringAsFixed(1)} kg of CO₂ '
          'through your ${summary.totalTrips} rides. That\'s equivalent to planting '
          '${(summary.totalCo2 / 21).toStringAsFixed(1)} trees! 🌱';
    }

    // Calories
    if (lower.contains('calorie') ||
        lower.contains('calories') ||
        lower.contains('burned')) {
      return 'You\'ve burned approximately ${summary.totalCalories.toInt()} calories '
          'across all your rides, $name! That\'s equivalent to '
          '${(summary.totalCalories / 300).toStringAsFixed(1)} full workout sessions. 🔥';
    }

    // Subscription / active plan
    if (lower.contains('subscription') ||
        lower.contains('plan') ||
        lower.contains('my plan')) {
      if (activeSub != null) {
        return 'Your active plan is "${activeSub.planName}" at ${activeSub.locationName}. '
            'It expires in ${activeSub.daysRemaining} day(s) (${activeSub.endDate.day}/${activeSub.endDate.month}/${activeSub.endDate.year}). '
            'Keep riding to get the most out of your subscription!';
      }
      return 'You don\'t have an active subscription yet, $name. '
          'Visit the Subscriptions screen to explore plans — '
          'subscribers get discounted rides and bonus coins!';
    }

    // Profile / stats
    if ((lower.contains('my stats') ||
        lower.contains('my profile') ||
        lower.contains('my info'))) {
      return 'Here\'s your quick summary, $name:\n'
          '• Total rides: ${summary.totalTrips}\n'
          '• Distance: ${summary.totalDistance.toStringAsFixed(1)} km\n'
          '• CO₂ saved: ${summary.totalCo2.toStringAsFixed(1)} kg\n'
          '• Calories burned: ${summary.totalCalories.toInt()} kcal\n'
          '• Avg speed: ${summary.avgSpeed.toStringAsFixed(1)} km/h\n\n'
          'Check your full activity dashboard for weekly and monthly breakdowns!';
    }

    // Speed
    if (lower.contains('speed') ||
        lower.contains('fast') ||
        lower.contains('avg speed')) {
      return 'Your average speed across all rides is ${summary.avgSpeed.toStringAsFixed(1)} km/h. '
          'Not bad, $name! Keep pushing for that Speed Demon badge! ⚡';
    }

    final backendReply = await ref
        .read(supportRepositoryProvider)
        .sendChatMessage(input);
    if (backendReply.trim().isNotEmpty) {
      return backendReply.trim();
    }

    return _getBotReply(input);
  }

  void _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    _ctrl.clear();
    setState(() {
      _messages.add(_Msg(text: trimmed, isUser: true));
      _isTyping = true;
    });
    _scrollDown();
    final delay = 800 + Random().nextInt(700);
    await Future.delayed(Duration(milliseconds: delay));
    final reply = await _getReply(trimmed);
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(_Msg(text: reply, isUser: false));
    });
    _scrollDown();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(child: _buildMessages(isDark)),
            if (_messages.length <= 2) _buildSuggestions(isDark),
            _buildInput(isDark),
          ],
        ),
      ),
    );
  }

  Widget _botAvatar(bool isDark) {
    return Container(
      width: 30.w,
      height: 30.w,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: SvgPicture.asset(
        AppAssets.iconLogoForTheme(isDark),
        width: 18.w,
        height: 18.w,
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevated : AppColors.grey100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16.w,
                color: isDark ? AppColors.white : AppColors.grey800,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              AppAssets.iconLogoForTheme(isDark),
              width: 24.w,
              height: 24.w,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thor AI',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      'Online · Newtra Support Bot',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Messages list ───────────────────────────────────────────────────────────

  Widget _buildMessages(bool isDark) {
    return ListView.builder(
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
      itemCount: _messages.length + (_isTyping ? 1 : 0),
      itemBuilder: (_, i) {
        if (_isTyping && i == _messages.length) {
          return _buildTypingBubble(isDark);
        }
        return _buildBubble(_messages[i], isDark);
      },
    );
  }

  Widget _buildBubble(_Msg msg, bool isDark) {
    final isUser = msg.isUser;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[_botAvatar(isDark), SizedBox(width: 8.w)],
          Flexible(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : (isDark ? AppColors.darkCard : AppColors.white),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16.r),
                  topRight: Radius.circular(16.r),
                  bottomLeft: isUser
                      ? Radius.circular(16.r)
                      : Radius.circular(4.r),
                  bottomRight: isUser
                      ? Radius.circular(4.r)
                      : Radius.circular(16.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14.sp,
                  height: 1.45,
                  color: isUser
                      ? Colors.white
                      : (isDark ? AppColors.grey100 : AppColors.grey800),
                ),
              ),
            ),
          ),
          if (isUser) SizedBox(width: 8.w),
        ],
      ),
    );
  }

  Widget _buildTypingBubble(bool isDark) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _botAvatar(isDark),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16.r),
                topRight: Radius.circular(16.r),
                bottomRight: Radius.circular(16.r),
                bottomLeft: Radius.circular(4.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: _dotAnim,
              builder: (context, child) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final phase = ((_dotAnim.value * 3) - i).clamp(0.0, 1.0);
                    final opacity = (sin(phase * pi)).abs().clamp(0.3, 1.0);
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 3.w),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7.w,
                          height: 7.w,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Suggestion chips ────────────────────────────────────────────────────────

  Widget _buildSuggestions(bool isDark) {
    return Container(
      height: 42.h,
      margin: EdgeInsets.only(bottom: 4.h),
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        itemBuilder: (_, i) {
          return GestureDetector(
            onTap: () => _send(_suggestions[i]),
            child: Container(
              margin: EdgeInsets.only(right: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Text(
                _suggestions[i],
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Input bar ───────────────────────────────────────────────────────────────

  Widget _buildInput(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 16.h),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevated : AppColors.grey50,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : Colors.black.withValues(alpha: 0.07),
                ),
              ),
              child: TextField(
                controller: _ctrl,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: isDark ? AppColors.white : AppColors.grey900,
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Ask Thor anything…',
                  hintStyle: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.grey400,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 10.h,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          GestureDetector(
            onTap: () => _send(_ctrl.text),
            child: Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.send_rounded, color: Colors.white, size: 18.w),
            ),
          ),
        ],
      ),
    );
  }
}
