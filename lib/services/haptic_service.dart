import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'storage_service.dart';

/// A service to manage haptic feedback (vibrations) throughout the app.
///
/// This singleton class centralizes the logic for triggering vibrations and
/// manages the user's preference for enabling or disabling them.
class HapticService with ChangeNotifier {
  HapticService._privateConstructor();
  static final HapticService instance = HapticService._privateConstructor();

  late bool _isEnabled;
  final _storage = StorageService.instance;

  bool get isEnabled => _isEnabled;

  /// Initializes the service by loading the user's preference from storage.
  /// Must be called once on app startup.
  Future<void> init() async {
    _isEnabled = await _storage.getHapticFeedbackEnabled();
  }

  /// Updates the user's preference for haptic feedback and saves it to storage.
  Future<void> setEnabled(bool enabled) async {
    if (_isEnabled == enabled) return;
    _isEnabled = enabled;
    await _storage.setHapticFeedbackEnabled(enabled);
    lightImpact(); // Provide feedback when the setting is changed
    notifyListeners();
  }

  /// Performs a light haptic feedback impact if haptics are enabled.
  /// Best for discrete actions like toggling a switch or tapping a button.
  void lightImpact() {
    if (_isEnabled) {
      HapticFeedback.lightImpact();
    }
  }

  /// Performs a medium haptic feedback impact if haptics are enabled.
  /// Best for more significant actions like opening a new screen.
  void mediumImpact() {
    if (_isEnabled) {
      HapticFeedback.mediumImpact();
    }
  }
} 