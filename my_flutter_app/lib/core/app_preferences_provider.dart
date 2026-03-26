import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for managing app-level preferences and first-launch state
class AppPreferencesProvider extends ChangeNotifier {
  static const String _onboardingCompletedKey = 'onboarding_completed';

  bool _onboardingCompleted = false;

  bool get onboardingCompleted => _onboardingCompleted;
  bool get shouldShowOnboarding => !_onboardingCompleted;

  AppPreferencesProvider() {
    _loadPreferences();
  }

  /// Load preferences from local storage
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingCompleted = prefs.getBool(_onboardingCompletedKey) ?? false;
      notifyListeners();
    } catch (e) {
      print('Error loading app preferences: $e');
    }
  }

  /// Mark onboarding as completed and persist to storage
  Future<void> markOnboardingComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, true);
      _onboardingCompleted = true;
      notifyListeners();
    } catch (e) {
      print('Error saving onboarding completion: $e');
    }
  }

  /// Reset onboarding (useful for testing or re-showing onboarding)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingCompletedKey, false);
      _onboardingCompleted = false;
      notifyListeners();
    } catch (e) {
      print('Error resetting onboarding: $e');
    }
  }
}
