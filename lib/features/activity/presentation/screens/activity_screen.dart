import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mj_card.dart';
import '../../data/models/activity_model.dart';
import '../providers/activity_provider.dart';

// ─── Category model ───────────────────────────────────────────────────────────

enum _Category { trips, distance, duration, calories, co2, speed }

extension _CategoryX on _Category {
  String get label {
    switch (this) {
      case _Category.trips:    return 'Trips';
      case _Category.distance: return 'Distance';
      case _Category.duration: return 'Duration';
      case _Category.calories: return 'Calories';
      case _Category.co2:      return 'CO2 Saved';
      case _Category.speed:    return 'Avg Speed';
    }
  }

  String get unit {
    switch (this) {
      case _Category.trips:    return '';
      case _Category.distance: return 'km';
      case _Category.duration: return 'min';
      case _Category.calories: return 'kcal';
      case _Category.co2:      return 'kg';
      case _Category.speed:    return 'km/h';
    }
  }

  Color get color {
    switch (this) {
      case _Category.trips:    return AppColors.primary;
      case _Category.distance: return AppColors.distance;
      case _Category.duration: return AppColors.info;
      case _Category.calories: return AppColors.calories;
      case _Category.co2:      return AppColors.success;
      case _Category.speed:    return AppColors.speed;
    }
  }

  IconData get icon {
    switch (this) {
      case _Category.trips:    return Icons.pedal_bike_rounded;
      case _Category.distance: return Icons.route_rounded;
      case _Category.duration: return Icons.timer_rounded;
      case _Category.calories: return Icons.local_fire_department_rounded;
      case _Category.co2:      return Icons.eco_rounded;
      case _Category.speed:    return Icons.speed_rounded;
    }
  }
}

// ─── Summary total helpers ───────────────────────────────────────────────────────────────────

String _totalForCat(_Category cat, ActivitySummary summary) {
  switch (cat) {
    case _Category.trips:
      return '${summary.totalTrips}';
    case _Category.distance:
      return '${summary.totalDistance.toStringAsFixed(1)} km';
    case _Category.duration:
      final h = summary.totalDurationMin ~/ 60;
      final m = summary.totalDurationMin % 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    case _Category.calories:
      return '${summary.totalCalories.toInt()} kcal';
    case _Category.co2:
      return '${summary.totalCo2.toStringAsFixed(1)} kg';
    case _Category.speed:
      return '${summary.avgSpeed.toStringAsFixed(1)} km/h';
  }
}

// ─── Mock data ────────────────────────────────────────────────────────────────

const _weekLabels  = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _monthLabels = ['W1', 'W2', 'W3', 'W4'];
const _qLabels     = ['Jan', 'Feb', 'Mar'];
const _yearLabels  = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// ─── Screen ───────────────────────────────────────────────────────────────────

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  _Category _cat    = _Category.trips;
  int       _preset = 0; // 0=Week 1=Month 2=3M 3=Year 4=Custom
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)),
    end:   DateTime.now(),
  );

  static const _presets = ['Week', 'Month', '3M', 'Year', 'Custom'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialGraphData());
  }

  Future<Map<String, List<GraphDataPoint>>> _loadGraphData() {
    final start = _formatDate(_range.start);
    final end = _formatDate(_range.end);
    return ref.read(activityProvider.notifier).loadGraphData(start, end);
  }

  Future<void> _loadInitialGraphData() async {
    final now = DateTime.now();
    final candidates = <(int, DateTimeRange)>[
      (
        0,
        DateTimeRange(
          start: now.subtract(const Duration(days: 6)),
          end: now,
        ),
      ),
      (
        1,
        DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: now,
        ),
      ),
      (
        2,
        DateTimeRange(
          start: DateTime(now.year, now.month - 2, 1),
          end: now,
        ),
      ),
      (
        3,
        DateTimeRange(
          start: DateTime(now.year, 1, 1),
          end: now,
        ),
      ),
    ];

    for (final candidate in candidates) {
      final preset = candidate.$1;
      final range = candidate.$2;
      setState(() {
        _preset = preset;
        _range = range;
      });

      final graphData = await _loadGraphData();
      if (!mounted) return;
      if (_hasAnyGraphPoints(graphData)) {
        final period = const ['week', 'month', 'quarter', 'year'][preset];
        ref.read(activityProvider.notifier).setPeriod(period);
        return;
      }
    }
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _hasAnyGraphPoints(Map<String, List<GraphDataPoint>> graphData) {
    return graphData.values.any((points) => points.isNotEmpty);
  }

  List<GraphDataPoint> _selectedGraphPoints(Map<String, List<GraphDataPoint>> graphData) {
    switch (_cat) {
      case _Category.distance:
        return graphData['distance'] ?? const [];
      case _Category.calories:
        return graphData['calories'] ?? const [];
      case _Category.duration:
        return graphData['time'] ?? const [];
      case _Category.trips:
      case _Category.co2:
      case _Category.speed:
        return graphData['distance'] ?? const [];
    }
  }

  bool _hasVisibleGraphData(Map<String, List<GraphDataPoint>> graphData) {
    switch (_cat) {
      case _Category.distance:
        return (graphData['distance'] ?? const []).isNotEmpty;
      case _Category.calories:
        return (graphData['calories'] ?? const []).isNotEmpty;
      case _Category.duration:
        return (graphData['time'] ?? const []).isNotEmpty;
      case _Category.trips:
      case _Category.co2:
        return (graphData['distance'] ?? const []).isNotEmpty;
      case _Category.speed:
        return (graphData['distance'] ?? const []).isNotEmpty &&
            (graphData['time'] ?? const []).isNotEmpty;
    }
  }

  List<String> get _labels {
    final graphData = ref.read(activityProvider).graphData;
    final points = _selectedGraphPoints(graphData);
    if (points.isNotEmpty) {
      return points.map((p) {
        final parsed = DateTime.tryParse(p.date);
        if (parsed == null) {
          final dayName = p.dayOfWeek;
          return dayName.length >= 3 ? dayName.substring(0, 3) : dayName;
        }
        if (_preset == 0) return DateFormat('EEE').format(parsed);
        return DateFormat('d MMM').format(parsed);
      }).toList();
    }

    switch (_preset) {
      case 1:  return _monthLabels;
      case 2:  return _qLabels;
      case 3:  return _yearLabels;
      default: return _weekLabels;
    }
  }

  List<FlSpot> _spotsFromGraphData() {
    final graphData = ref.read(activityProvider).graphData;

    // Map category to graph data key
    String? graphKey;
    switch (_cat) {
      case _Category.distance:
        graphKey = 'distance';
        break;
      case _Category.calories:
        graphKey = 'calories';
        break;
      case _Category.duration:
        graphKey = 'time';
        break;
      default:
        graphKey = null;
    }

    if (graphKey != null) {
      final points = graphData[graphKey] ?? [];
      if (points.isNotEmpty) {
        return List.generate(points.length, (i) => FlSpot(i.toDouble(), points[i].value));
      }
    }

    // For trips/co2/speed that don't have dedicated graph endpoints,
    // derive from distance data if available
    final distPoints = graphData['distance'] ?? [];
    if (distPoints.isNotEmpty) {
      switch (_cat) {
        case _Category.co2:
          return List.generate(distPoints.length, (i) => FlSpot(i.toDouble(), distPoints[i].value * 0.21));
        case _Category.trips:
          return List.generate(distPoints.length, (i) => FlSpot(i.toDouble(), distPoints[i].value > 0 ? 1 : 0));
        case _Category.speed:
          final timePoints = graphData['time'] ?? [];
          if (timePoints.isNotEmpty && timePoints.length == distPoints.length) {
            return List.generate(distPoints.length, (i) {
              final hours = timePoints[i].value;
              return FlSpot(i.toDouble(), hours > 0 ? distPoints[i].value / hours : 0);
            });
          }
          return List.generate(distPoints.length, (i) => FlSpot(i.toDouble(), 0));
        default:
          break;
      }
    }

    // Fall back to zeros
    final fallbackLen = _labels.length;
    return List.generate(fallbackLen, (i) => FlSpot(i.toDouble(), 0));
  }

  void _applyPreset(int i) {
    final now = DateTime.now();
    DateTimeRange range;
    switch (i) {
      case 1:
        range = DateTimeRange(start: DateTime(now.year, now.month, 1), end: now);
        break;
      case 2:
        range = DateTimeRange(start: DateTime(now.year, now.month - 2, 1), end: now);
        break;
      case 3:
        range = DateTimeRange(start: DateTime(now.year, 1, 1), end: now);
        break;
      default:
        range = DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now);
    }
    setState(() { _preset = i; _range = range; });
    // Sync period with provider
    final period = const ['week', 'month', 'quarter', 'year', 'week'][i];
    ref.read(activityProvider.notifier).setPeriod(period);
    _loadGraphData();
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context:            context,
      firstDate:          DateTime(2020),
      lastDate:           DateTime.now(),
      initialDateRange:   _range,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { _range = picked; _preset = 4; });
      _loadGraphData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? AppColors.darkSurface : const Color(0xFFF4F6F9);
    final actState = ref.watch(activityProvider);
    final summary  = actState.summary;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHeader(context, isDark)),

            // ── Preset chips ──────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildPresetRow(isDark)),

            // ── Category chips ────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildCategoryRow(isDark)),

            // ── Line chart ────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildChart(context, isDark, summary)),

            // ── Summary header ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20.w, 28.h, 20.w, 4.h),
                child: Text(
                  'Summary',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // ── Stats grid ────────────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 36.h),
              sliver: SliverGrid.count(
                crossAxisCount:  2,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: 1.55,
                children: _Category.values
                    .map((c) => _buildStatCard(context, c, isDark, summary))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: Icon(Icons.arrow_back_ios_new_rounded, size: 16.w,
                  color: isDark ? AppColors.white : AppColors.grey900),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${DateFormat('MMM d').format(_range.start)} – ${DateFormat('MMM d, yyyy').format(_range.end)}',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.grey500),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _pickRange,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 9.h),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(14.r),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calendar_month_rounded, size: 16.w, color: AppColors.primary),
                  SizedBox(width: 6.w),
                  Text(
                    'Filter',
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Preset row ─────────────────────────────────────────────────────────────

  Widget _buildPresetRow(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 0),
      child: Row(
        children: List.generate(_presets.length, (i) {
          final sel = _preset == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => i == 4 ? _pickRange() : _applyPreset(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < _presets.length - 1 ? 8.w : 0),
                padding: EdgeInsets.symmetric(vertical: 9.h),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary : (isDark ? AppColors.darkCard : AppColors.white),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    child: Text(
                      _presets[i],
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: sel ? AppColors.white : (isDark ? AppColors.grey300 : AppColors.grey700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Category chips ─────────────────────────────────────────────────────────

  Widget _buildCategoryRow(bool isDark) {
    return Padding(
      padding: EdgeInsets.only(top: 18.h),
      child: SizedBox(
        height: 42.h,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          children: _Category.values.map((cat) {
            final sel = _cat == cat;
            return Padding(
              padding: EdgeInsets.only(right: 10.w),
              child: GestureDetector(
                onTap: () => setState(() => _cat = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 0),
                  decoration: BoxDecoration(
                    color: sel
                        ? cat.color.withValues(alpha: 0.14)
                        : (isDark ? AppColors.darkCard : AppColors.white),
                    borderRadius: BorderRadius.circular(21.r),
                    border: Border.all(
                      color: sel ? cat.color : Colors.transparent,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 15.w, color: sel ? cat.color : AppColors.grey500),
                      SizedBox(width: 6.w),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? cat.color : (isDark ? AppColors.grey400 : AppColors.grey600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Line chart ─────────────────────────────────────────────────────────────

  Widget _buildChart(BuildContext context, bool isDark, ActivitySummary summary) {
    final color  = _cat.color;
    final labels = _labels;
    final spots  = _spotsFromGraphData();
    final total  = _totalForCat(_cat, summary);
    final graphData = ref.watch(activityProvider).graphData;
    final hasVisibleGraphData = _hasVisibleGraphData(graphData);
    final maxY = spots.fold<double>(0, (max, spot) => spot.y > max ? spot.y : max);
    final chartMaxY = maxY <= 0 ? 1.0 : maxY * 1.15;
    final labelStride = labels.length <= 6 ? 1 : (labels.length / 6).ceil();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
      child: MjCard(
        padding: EdgeInsets.fromLTRB(16.w, 20.h, 12.w, 12.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chart title row
            Row(
              children: [
                Container(
                  width: 4.w,
                  height: 22.h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    _cat.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    total,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold, color: color),
                  ),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Text(
              _cat.unit.isNotEmpty ? 'in ${_cat.unit}' : 'total count',
              style: TextStyle(fontSize: 11.sp, color: AppColors.grey500),
            ),
            SizedBox(height: 24.h),

            // Chart
            SizedBox(
              height: 220.h,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 380),
                child: LineChart(
                  key: ValueKey(_cat.name + _preset.toString()),
                  LineChartData(
                    clipData: const FlClipData.all(),
                    minY: 0,
                    maxY: chartMaxY,
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => isDark ? AppColors.darkElevated : AppColors.white,
                        tooltipRoundedRadius: 10,
                        getTooltipItems: (spots) => spots.map((s) {
                          final unit = _cat.unit;
                          return LineTooltipItem(
                            '${s.y % 1 == 0 ? s.y.toInt() : s.y.toStringAsFixed(1)}${unit.isNotEmpty ? ' $unit' : ''}',
                            TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.sp,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: isDark ? Colors.white10 : AppColors.grey200,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42.w,
                          getTitlesWidget: (v, _) => Text(
                            _formatAxisVal(v),
                            style: TextStyle(fontSize: 10.sp, color: AppColors.grey500),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28.h,
                          interval: 1,
                          getTitlesWidget: (v, _) {
                            final idx = v.toInt();
                            if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                            if (idx != labels.length - 1 && idx % labelStride != 0) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: EdgeInsets.only(top: 8.h),
                              child: Text(
                                labels[idx],
                                style: TextStyle(fontSize: 10.sp, color: AppColors.grey500),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots:          spots,
                        isCurved:       true,
                        curveSmoothness: 0.35,
                        color:          color,
                        barWidth:       2.5,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                            radius:      4,
                            color:       color,
                            strokeWidth: 2,
                            strokeColor: isDark ? AppColors.darkCard : AppColors.white,
                          ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end:   Alignment.bottomCenter,
                            colors: [
                              color.withValues(alpha: 0.28),
                              color.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!hasVisibleGraphData)
              Padding(
                padding: EdgeInsets.only(top: 12.h, left: 4.w),
                child: Text(
                  'No ${_cat.label.toLowerCase()} data in this range yet.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.grey500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatAxisVal(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v % 1 == 0) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }

  // ── Stat card ──────────────────────────────────────────────────────────────

  Widget _buildStatCard(BuildContext context, _Category cat, bool isDark, ActivitySummary summary) {
    final sel = _cat == cat;
    final total = _totalForCat(cat, summary);
    return GestureDetector(
      onTap: () => setState(() => _cat = cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: sel
              ? cat.color.withValues(alpha: 0.12)
              : (isDark ? AppColors.darkCard : AppColors.white),
          borderRadius: BorderRadius.circular(18.r),
          border: sel ? Border.all(color: cat.color, width: 1.5) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: cat.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(cat.icon, size: 16.w, color: cat.color),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    total,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(cat.label, style: TextStyle(fontSize: 11.sp, color: AppColors.grey500)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
