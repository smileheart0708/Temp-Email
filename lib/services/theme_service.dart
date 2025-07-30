import 'package:flutter/material.dart';
import 'storage_service.dart';

/// A service to manage theme-related settings, like theme mode and dynamic color.
///
/// This singleton class centralizes the logic for theme management and notifies
/// listeners when settings change, allowing the UI to reactively update.
class ThemeService with ChangeNotifier {
  ThemeService._privateConstructor();
  static final ThemeService instance = ThemeService._privateConstructor();

  final _storage = StorageService.instance;

  late ThemeMode _themeMode;
  late bool _useDynamicColor;

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;

  /// Initializes the service by loading the user's theme preferences from storage.
  /// Must be called once on app startup.
  Future<void> init() async {
    final (themeMode, useDynamicColor) = await _storage.getThemeSettings();
    _themeMode = themeMode;
    _useDynamicColor = useDynamicColor;
  }

  /// Updates the application's theme mode and persists the change.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    // Persist the change to storage
    await _storage.saveThemeSettings(_themeMode, _useDynamicColor);
    // Notify listeners to rebuild the UI
    notifyListeners();
  }

  /// Toggles the use of dynamic color (Material You) and persists the change.
  Future<void> setUseDynamicColor(bool enabled) async {
    if (_useDynamicColor == enabled) return;
    _useDynamicColor = enabled;
    // Persist the change to storage
    await _storage.saveThemeSettings(_themeMode, _useDynamicColor);
    // Notify listeners to rebuild the UI
    notifyListeners();
  }
} 