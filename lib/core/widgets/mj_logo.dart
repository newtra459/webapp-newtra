import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants/app_assets.dart';

class MjLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final bool useIconMark;

  const MjLogo({
    super.key,
    this.width,
    this.height,
    this.useIconMark = false,
  });

  const MjLogo.full({
    super.key,
    this.width,
    this.height,
  }) : useIconMark = false;

  const MjLogo.icon({
    super.key,
    this.width,
    this.height,
  }) : useIconMark = true;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    final String svgAsset;
    if (useIconMark) {
      svgAsset = AppAssets.iconLogoForBrightness(brightness);
    } else {
      svgAsset = AppAssets.fullLogoForBrightness(brightness);
    }

    return SvgPicture.asset(
      svgAsset,
      width: width,
      height: height,
    );
  }
}
