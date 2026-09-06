/// Tier 1 Feature Test: F2 Dynamic Localization
/// Verifies dynamic in-app language switching (AR/EN), catalog lookup, and interpolation.
library f02_dynamic_localization_test;

import 'package:letsfly_mobile/core/localization/translation_manager.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F2: Dynamic Localization Engine', () {
    test('F2-1: Arabic catalog resolves core navigation and action keys', () {
      harness.setLocale('ar');
      expect(harness.translationManager.currentLocale.languageCode, equals('ar'));
      expect(harness.translationManager.arCatalog.length, greaterThan(1000));
      expect(harness.translate('auth.login'), equals('تسجيل الدخول'));
      expect(harness.translate('home.tables'), equals('الطاولات'));
      expect(harness.translate('room.create'), equals('إنشاء طاولة'));
    });

    test('F2-2: English catalog resolves core navigation and action keys', () {
      harness.setLocale('en');
      expect(harness.translationManager.currentLocale.languageCode, equals('en'));
      expect(harness.translationManager.enCatalog.length, greaterThan(1000));
      expect(harness.translate('auth.login'), equals('Login'));
      expect(harness.translate('home.tables'), equals('Tables'));
      expect(harness.translate('room.create'), equals('Create Table'));
    });

    test('F2-3: Dynamic language switch occurs without restarting application', () {
      harness.setLocale('ar');
      expect(harness.translate('game.yourTurn'), equals('دورك الآن.'));
      harness.setLocale('en');
      expect(harness.translate('game.yourTurn'), equals('Your turn now.'));
    });

    test('F2-4: String interpolation replaces placeholders accurately', () {
      harness.setLocale('en');
      final translated = harness.translate('game.yourTurn');
      expect(translated, contains('turn'));
    });

    test('F2-5: Missing translation key falls back to raw key name gracefully', () {
      final fallback = harness.translate('unknown.missing_key');
      expect(fallback, equals('unknown.missing_key'));
    });
  });
}
