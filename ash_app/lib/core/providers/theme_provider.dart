import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

// Theme State
class ThemeState {
  final ThemeMode themeMode;
  final bool isDarkMode;

  const ThemeState({
    this.themeMode = ThemeMode.system,
    this.isDarkMode = false,
  });

  ThemeState copyWith({
    ThemeMode? themeMode,
    bool? isDarkMode,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

// Theme Notifier
class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState()) {
    _loadTheme();
  }

  // Load saved theme preference
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeIndex = prefs.getInt(AppConfig.themeKey) ?? 0;
      final themeMode = ThemeMode.values[themeIndex];

      state = state.copyWith(
        themeMode: themeMode,
        isDarkMode: themeMode == ThemeMode.dark,
      );
    } catch (e) {
      // Use system default if loading fails
      state = const ThemeState();
    }
  }

  // Set theme mode
  Future<void> setThemeMode(ThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(AppConfig.themeKey, mode.index);

      state = state.copyWith(
        themeMode: mode,
        isDarkMode: mode == ThemeMode.dark,
      );
    } catch (e) {
      // Handle error silently
      // Failed to save theme preference: $e
    }
  }

  // Toggle between light and dark mode
  Future<void> toggleTheme() async {
    final newMode = state.isDarkMode ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(newMode);
  }

  // Set light mode
  Future<void> setLightMode() async {
    await setThemeMode(ThemeMode.light);
  }

  // Set dark mode
  Future<void> setDarkMode() async {
    await setThemeMode(ThemeMode.dark);
  }

  // Set system mode
  Future<void> setSystemMode() async {
    await setThemeMode(ThemeMode.system);
  }
}

// Provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});

// Convenience providers
final currentThemeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(themeProvider).themeMode;
});

final isDarkModeProvider = Provider<bool>((ref) {
  return ref.watch(themeProvider).isDarkMode;
});
