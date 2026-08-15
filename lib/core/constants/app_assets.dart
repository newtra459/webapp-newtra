import 'dart:ui';

class AppAssets {
  AppAssets._();

  // Existing names are kept for compatibility:
  // "dark" means artwork intended for dark surfaces, and "light" means artwork
  // intended for light surfaces.
  static const String fullLogoDark = 'assets/images/logo/newtra_full_dark.svg';
  static const String fullLogoLight =
      'assets/images/logo/newtra_full_light.svg';

  static const String iconLogoDark = 'assets/images/logo/newtra_icon_dark.svg';
  static const String iconLogoLight =
      'assets/images/logo/newtra_icon_light.svg';

  static const String fullLogoOnDark = fullLogoDark;
  static const String fullLogoOnLight = fullLogoLight;
  static const String iconLogoOnDark = iconLogoDark;
  static const String iconLogoOnLight = iconLogoLight;

  static const String iconMarkPngOnDark =
      'assets/images/logo/icon_mark_white_green.png';
  static const String iconMarkPngOnLight =
      'assets/images/logo/icon_mark_color.png';
  static const String launcherIcon = 'assets/images/logo/app_icon.png';

  static String fullLogoForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? fullLogoOnDark : fullLogoOnLight;
  }

  static String fullLogoForTheme(bool isDark) {
    return isDark ? fullLogoOnDark : fullLogoOnLight;
  }

  static String iconLogoForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? iconLogoOnDark : iconLogoOnLight;
  }

  static String iconLogoForTheme(bool isDark) {
    return isDark ? iconLogoOnDark : iconLogoOnLight;
  }

  static String iconMarkPngForBrightness(Brightness brightness) {
    return brightness == Brightness.dark
        ? iconMarkPngOnDark
        : iconMarkPngOnLight;
  }

  static String iconMarkPngForTheme(bool isDark) {
    return isDark ? iconMarkPngOnDark : iconMarkPngOnLight;
  }
}
