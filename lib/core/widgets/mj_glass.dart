import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Apple-style frosted glass container.
///
/// Blurs whatever is behind it and overlays a translucent tint + subtle border.
/// Works well over maps, images, and gradient backgrounds.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  /// Blur intensity (default 18 matches Apple's frosted glass look).
  final double blur;

  /// Override the tint colour. Defaults to white/black at ~70% based on theme.
  final Color? tint;

  /// Override the border colour. Defaults to a soft white glint.
  final Color? borderColor;
  final double borderWidth;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.borderRadius,
    this.blur = 18,
    this.tint,
    this.borderColor,
    this.borderWidth = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveTint = tint ??
        (isDark
            ? Colors.black.withValues(alpha: 0.42)
            : Colors.white.withValues(alpha: 0.72));

    final effectiveBorder = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.85));

    final radius = borderRadius ?? BorderRadius.circular(16.r);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveTint,
            borderRadius: radius,
            border: Border.all(
              color: effectiveBorder,
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
