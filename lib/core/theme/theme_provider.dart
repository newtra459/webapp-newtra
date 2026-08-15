import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../storage/local_storage.dart';

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  ThemeNotifier() : super(ThemeMode.dark) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final stored = await LocalStorage.getString('theme_mode');
    if (stored != null) {
      state = ThemeMode.values.firstWhere(
        (e) => e.name == stored,
        orElse: () => ThemeMode.dark,
      );
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    await LocalStorage.setString('theme_mode', mode.name);
  }

  Future<void> toggleTheme() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setTheme(newMode);
  }
}
