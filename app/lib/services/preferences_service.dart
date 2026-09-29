import 'package:shared_preferences/shared_preferences.dart';

/// Wraps [SharedPreferences] for the first-launch onboarding flag (§7.7).
class PreferencesService {
  PreferencesService(this._prefs);

  static const onboardingKey = 'has_completed_onboarding';

  final SharedPreferences _prefs;

  static Future<PreferencesService> instance() async =>
      PreferencesService(await SharedPreferences.getInstance());

  bool get hasCompletedOnboarding => _prefs.getBool(onboardingKey) ?? false;

  Future<void> setOnboardingCompleted() => _prefs.setBool(onboardingKey, true);
}
