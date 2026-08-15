import 'dart:ui' show DisplayFeatureState, DisplayFeatureType;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Responsive layout breakpoints and foldable-device helpers.
///
/// Form-factor decision tree:
///   shortest side < 600 dp         → phone  (bottom nav)
///   foldable in half-open posture   → phone  (bottom nav, single panel)
///   shortest side ≥ 600 dp         → tablet (compact rail)
///   width ≥ 840 dp                 → wide tablet / landscape foldable (extended rail + labels)
class AppBreakpoints {
  AppBreakpoints._();

  /// Phones / compact foldables when closed.
  static const double tabletMin = 600;

  /// Threshold where the nav rail shows labels alongside icons.
  static const double wideTabletMin = 840;

  /// Maximum width for readable content columns (centres text on large screens).
  static const double contentMaxWidth = 600;

  // ── Form-factor helpers ───────────────────────────────────────────────────

  /// True when the device has a physical hinge or soft fold that is currently
  /// in the half-opened (book / tabletop) posture.
  /// On these devices the app should stay within a single display panel.
  static bool isFoldHalfOpen(BuildContext context) =>
      MediaQuery.of(context).displayFeatures.any(
        (f) =>
            (f.type == DisplayFeatureType.fold ||
                f.type == DisplayFeatureType.hinge) &&
            f.state == DisplayFeatureState.postureHalfOpened,
      );

  /// Returns the screen-space [Rect] of a fold crease or physical hinge, if
  /// present. Use this to add padding that avoids rendering content over the
  /// device crease.
  static Rect? foldBounds(BuildContext context) {
    for (final f in MediaQuery.of(context).displayFeatures) {
      if (f.type == DisplayFeatureType.fold ||
          f.type == DisplayFeatureType.hinge) return f.bounds;
    }
    return null;
  }

  /// True when the shell should use a left-side navigation rail instead of a
  /// bottom navigation bar (tablet or unfolded foldable).
  static bool useRailNav(BuildContext context) {
    if (isFoldHalfOpen(context)) return false;
    return MediaQuery.of(context).size.shortestSide >= tabletMin;
  }

  /// True when the rail should show icon + label rows (wide tablet or
  /// landscape foldable).
  static bool useWideRailNav(BuildContext context) =>
      useRailNav(context) &&
      MediaQuery.of(context).size.width >= wideTabletMin;

  /// Convenience — kept for callers that only need a simple phone/tablet check.
  static bool isTablet(BuildContext context) => useRailNav(context);
}

class AppSizes {
  AppSizes._();

  // Padding & Margin
  static double get xs => 4.w;
  static double get sm => 8.w;
  static double get md => 16.w;
  static double get lg => 24.w;
  static double get xl => 32.w;
  static double get xxl => 48.w;

  // Border Radius
  static double get radiusSm => 8.r;
  static double get radiusMd => 12.r;
  static double get radiusLg => 16.r;
  static double get radiusXl => 24.r;
  static double get radiusFull => 999.r;

  // Icon
  static double get iconSm => 18.w;
  static double get iconMd => 24.w;
  static double get iconLg => 32.w;
  static double get iconXl => 48.w;

  // Button
  static double get buttonHeight => 52.h;
  static double get buttonHeightSm => 40.h;

  // Avatar
  static double get avatarSm => 36.w;
  static double get avatarMd => 48.w;
  static double get avatarLg => 72.w;
  static double get avatarXl => 100.w;

  // Card
  static double get cardElevation => 2;

  // Bottom nav
  static double get bottomNavHeight => 64.h;

  // Map markers
  static double get markerSize => 40.w;
}
