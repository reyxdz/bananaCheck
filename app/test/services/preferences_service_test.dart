import 'package:banana_classifier/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('onboarding flag defaults to false and persists once set', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await PreferencesService.instance();
    expect(service.hasCompletedOnboarding, isFalse);

    await service.setOnboardingCompleted();
    final reloaded = await PreferencesService.instance();
    expect(reloaded.hasCompletedOnboarding, isTrue);
  });
}
