import 'dart:convert';
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
  // --- Deprecated Keys ---
  // static const String _apiKey = 'api_key'; // Replaced by _idataiverApiKey
  // static const String _requestUrl = 'request_url'; // No longer used

  // --- New Email Service Keys ---
  static const String _providerSuffixes = 'provider_suffixes_'; // Prefix, e.g., provider_suffixes_Mailcx
  static const String _suffixSelectionMode = 'suffix_selection_mode';
  static const String _fixedSuffixSelection = 'fixed_suffix_selection';

  // --- Existing Keys ---
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


  // --- Provider Suffix Settings ---
  Future<void> saveProviderSuffixes(String providerName, List<Map<String, dynamic>> suffixes) async {
    final key = '$_providerSuffixes$providerName';
    await _prefs.setString(key, json.encode(suffixes));
  }

  Future<List<Map<String, dynamic>>?> getProviderSuffixes(String providerName) async {
    final key = '$_providerSuffixes$providerName';
    final jsonString = _prefs.getString(key);
    if (jsonString != null) {
      return (json.decode(jsonString) as List).cast<Map<String, dynamic>>();
    }
    return null;
  }

  // --- Suffix Selection Mode ---
  Future<void> saveSuffixSelectionMode(String mode) async {
    await _prefs.setString(_suffixSelectionMode, mode);
  }

  Future<String> getSuffixSelectionMode() async {
    // Default to 'fixed'
    return _prefs.getString(_suffixSelectionMode) ?? 'fixed';
  }

  // --- Fixed Suffix Selection ---
  Future<void> saveFixedSuffixSelection(String suffix) async {
    await _prefs.setString(_fixedSuffixSelection, suffix);
  }

  Future<String?> getFixedSuffixSelection() async {
    return _prefs.getString(_fixedSuffixSelection);
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