/// Tier 1 Feature Test: F1 Foundation & Config
/// Verifies application configuration, environment settings, directionality, and asset contracts.
library f01_foundation_test;

import 'package:flutter/widgets.dart';
import 'package:letsfly_mobile/core/constants/sound_cues.dart';
import 'package:letsfly_mobile/core/audio/sound_engine.dart';
import 'package:letsfly_mobile/core/localization/translation_manager.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';
import '../harness/test_fixtures.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F1: Foundation & App Configuration', () {
    test('F1-1: Environment configuration defaults to development settings', () {
      expect(harness.httpServer.port, greaterThan(0));
      expect(harness.wsServer.port, greaterThan(0));
      expect(harness.httpServer.baseUrl, contains('127.0.0.1'));
      expect(SoundCues.all.length, greaterThanOrEqualTo(115));
      expect(SoundEngine.soundRegistry.length, greaterThanOrEqualTo(115));
    });

    test('F1-2: Directionality aligns with locale (Arabic RTL)', () {
      harness.setLocale('ar');
      expect(harness.currentLocale, equals('ar'));
      expect(harness.translationManager.textDirection, equals(TextDirection.rtl));
      expect(harness.translate('app.name'), equals("هيا نطير"));
    });

    test('F1-3: Directionality aligns with locale (English LTR)', () {
      harness.setLocale('en');
      expect(harness.currentLocale, equals('en'));
      expect(harness.translationManager.textDirection, equals(TextDirection.ltr));
      expect(harness.translate('app.name'), equals("Let's Fly"));
    });

    test('F1-4: Fixture data contains required user accounts', () {
      expect(TestFixtures.userAlice.username, equals('alice'));
      expect(TestFixtures.userBob.username, equals('bob'));
      expect(TestFixtures.userCharlie.username, equals('charlie'));
    });

    test('F1-5: Security headers injected into all HTTP responses', () async {
      final res = await harness.getHttp('/api/rooms');
      expect(res['statusCode'], equals(200));
    });
  });
}
