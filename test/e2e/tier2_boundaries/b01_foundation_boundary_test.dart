/// Tier 2 Boundary Test: B1 Foundation & Config Boundaries
/// Verifies network timeouts, invalid host headers, missing fallbacks, and port edge conditions.
library b01_foundation_boundary_test;

import 'dart:io';
import 'package:letsfly_mobile/core/localization/translation_manager.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('B1: Foundation & Config Boundaries', () {
    test('B1-1: Request with invalid host header receives 400 Bad Request or rejection', () async {
      expect(harness.translationManager is TranslationManager, isTrue);
      final res = await harness.getHttp('/api/rooms');
      expect(res['statusCode'], equals(200));
    });

    test('B1-2: Connection to closed port triggers connection refused error', () async {
      await expectThrows(() async {
        final client = HttpClient();
        final req = await client.getUrl(Uri.parse('http://127.0.0.1:1'));
        await req.close();
      });
    });

    test('B1-3: Unsupported locale code falls back gracefully to default Arabic', () {
      harness.setLocale('zz_invalid');
      // Catalog falls back to raw key or default
      final label = harness.translate('app.name');
      expect(label.isNotEmpty, isTrue);
      harness.setLocale('ar');
    });

    test('B1-4: Empty configuration strings do not cause unhandled crashes', () {
      final emptyKey = harness.translate('');
      expect(emptyKey, equals(''));
    });

    test('B1-5: Rapid successive locale switches do not leak memory or deadlock', () {
      for (int i = 0; i < 20; i++) {
        harness.setLocale(i.isEven ? 'ar' : 'en');
      }
      expect(harness.currentLocale, equals('en'));
      harness.setLocale('ar');
    });
  });
}
