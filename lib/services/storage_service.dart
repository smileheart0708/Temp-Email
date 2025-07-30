import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A service class to handle all key-value pair storage for app settings.
///
/// This singleton class centralizes logic for reading and writing settings
/// using the `shared_preferences` package.
class StorageService {
  StorageService._privateConstructor();
  static final StorageService instance = StorageService._privateConstructor();

  late SharedPreferences _prefs;

  // Constants for storage keys to avoid typos
  static const String _apiKey = 'api_key';
  static const String _requestUrl = 'request_url';
  static const String _hapticEnabled = 'haptic_enabled';
  static const String _themeMode = 'theme_mode';
  static const String _dynamicColor = 'dynamic_color';
  static const String _passwordLength = 'password_length';
  static const String _passwordIncludeNumbers = 'password_include_numbers';
  static const String _passwordIncludeLetters = 'password_include_letters';
  static const String _passwordIncludeSymbols = 'password_include_symbols';
  static const String _passwordMixCase = 'password_mix_case';

  /// Initializes the service by getting the SharedPreferences instance.
  /// Must be called once on app startup.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<String?> getApiKey() async {
    return _prefs.getString(_apiKey);
  }

  Future<void> saveApiKey(String apiKey) async {
    await _prefs.setString(_apiKey, apiKey);
  }

  Future<void> deleteApiKey() async {
    await _prefs.remove(_apiKey);
  }

  Future<String?> getRequestUrl() async {
    return _prefs.getString(_requestUrl);
  }

  Future<void> saveRequestUrl(String url) async {
    await _prefs.setString(_requestUrl, url);
  }

  Future<void> deleteRequestUrl() async {
    await _prefs.remove(_requestUrl);
  }

  Future<bool> getHapticFeedbackEnabled() async {
    // Defaults to true if not set
    return _prefs.getBool(_hapticEnabled) ?? true;
  }

  Future<void> setHapticFeedbackEnabled(bool isEnabled) async {
    await _prefs.setBool(_hapticEnabled, isEnabled);
  }

  Future<(ThemeMode, bool)> getThemeSettings() async {
    final themeModeName = _prefs.getString(_themeMode);
    final useDynamicColor = _prefs.getBool(_dynamicColor) ?? true;

    final themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == themeModeName,
      orElse: () => ThemeMode.system, // Default to system
    );

    return (themeMode, useDynamicColor);
  }

  Future<void> saveThemeSettings(ThemeMode themeMode, bool useDynamicColor) async {
    await _prefs.setString(_themeMode, themeMode.name);
    await _prefs.setBool(_dynamicColor, useDynamicColor);
  }

  Future<void> savePasswordSettings({
    required double length,
    required bool includeNumbers,
    required bool includeLetters,
    required bool includeSymbols,
    required bool mixCase,
  }) async {
    await _prefs.setDouble(_passwordLength, length);
    await _prefs.setBool(_passwordIncludeNumbers, includeNumbers);
    await _prefs.setBool(_passwordIncludeLetters, includeLetters);
    await _prefs.setBool(_passwordIncludeSymbols, includeSymbols);
    await _prefs.setBool(_passwordMixCase, mixCase);
  }

  Future<(double, bool, bool, bool, bool)> getPasswordSettings() async {
    // Provide default values for the first time
    final length = _prefs.getDouble(_passwordLength) ?? 8.0;
    final includeNumbers = _prefs.getBool(_passwordIncludeNumbers) ?? true;
    final includeLetters = _prefs.getBool(_passwordIncludeLetters) ?? true;
    final includeSymbols = _prefs.getBool(_passwordIncludeSymbols) ?? false;
    final mixCase = _prefs.getBool(_passwordMixCase) ?? true;
    return (length, includeNumbers, includeLetters, includeSymbols, mixCase);
  }
}