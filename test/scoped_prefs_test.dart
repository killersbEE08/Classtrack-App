// Verifies the per-user preference isolation that fixes the shared-device
// privacy bug where one account inherited another's accent colour / API key.
//
// ScopedPrefs namespaces every key by uid and does a one-time migration of any
// legacy device-global value into the current user's namespace, deleting the
// global copy so it can't leak to the next account.

import 'package:classtrack/core/constants/app_constants.dart';
import 'package:classtrack/core/providers/app_settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScopedPrefs per-user isolation', () {
    test('one account cannot see another account\'s value', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final userA = ScopedPrefs(prefs, 'userA');
      final userB = ScopedPrefs(prefs, 'userB');

      await userA.setInt(AppConstants.prefsAccentColor, 0xFF00FF00);

      expect(userA.getInt(AppConstants.prefsAccentColor), 0xFF00FF00);
      expect(userB.getInt(AppConstants.prefsAccentColor), isNull,
          reason: "userB must not inherit userA's accent colour");
    });

    test('signed-out scope reads defaults and never persists', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final anon = ScopedPrefs(prefs, null);

      await anon.setString(AppConstants.prefsGeminiKey, 'secret-key');

      expect(anon.isActive, isFalse);
      expect(anon.getString(AppConstants.prefsGeminiKey), isNull);
      expect(prefs.getKeys(), isEmpty,
          reason: 'nothing may be written while signed out');
    });

    test('legacy global value migrates to first user, then is removed',
        () async {
      // Simulate a pre-update install that stored the accent colour globally.
      SharedPreferences.setMockInitialValues({
        AppConstants.prefsAccentColor: 0xFFAABBCC,
      });
      final prefs = await SharedPreferences.getInstance();

      final firstUser = ScopedPrefs(prefs, 'firstUser');
      // First read adopts the legacy value for the (typically owner) account…
      expect(firstUser.getInt(AppConstants.prefsAccentColor), 0xFFAABBCC);
      // …and clears the global key so it can't bleed to anyone else.
      expect(prefs.containsKey(AppConstants.prefsAccentColor), isFalse);

      // A different account started afterwards gets the default, not the leak.
      final secondUser = ScopedPrefs(prefs, 'secondUser');
      expect(secondUser.getInt(AppConstants.prefsAccentColor), isNull);
    });

    test('remove clears only the current user\'s key', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final userA = ScopedPrefs(prefs, 'userA');
      final userB = ScopedPrefs(prefs, 'userB');

      await userA.setInt(AppConstants.prefsAccentColor, 0x11223344);
      await userB.setInt(AppConstants.prefsAccentColor, 0x55667788);

      await userA.remove(AppConstants.prefsAccentColor);

      expect(userA.getInt(AppConstants.prefsAccentColor), isNull);
      expect(userB.getInt(AppConstants.prefsAccentColor), 0x55667788,
          reason: "removing userA's value must not touch userB's");
    });
  });
}
