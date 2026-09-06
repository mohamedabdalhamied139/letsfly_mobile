/// Tier 1 Feature Test: F3 Pattern Engine
/// Verifies dynamic regex pattern resolution of server-generated action strings into English.
library f03_pattern_engine_test;

import 'package:letsfly_mobile/core/localization/pattern_resolver.dart';
import 'package:letsfly_mobile/core/localization/translation_manager.dart';
import '../harness/test_framework.dart';
import '../harness/client_harness.dart';

void registerTests(LetsFlyTestHarness harness) {
  describe('F3: Dynamic Regex Pattern Engine', () {
    test('F3-1: Resolves card played action pattern in English mode', () {
      harness.setLocale('en');
      final result = harness.resolvePattern('لعب أحمد ورقة أحمر 7.');
      expect(result, equals('أحمد played أحمر 7.'));
      expect(PatternResolver.sanitizeRegex(r'a\-b\ c'), equals('a-b c'));
    });

    test('F3-2: Resolves card drawn action pattern in English mode', () {
      harness.setLocale('en');
      final result = harness.resolvePattern('سحب أحمد ورقة من السحب.');
      expect(result, equals('أحمد drew a card from the deck.'));
    });

    test('F3-3: Resolves room join action pattern in English mode', () {
      harness.setLocale('en');
      final result = harness.resolvePattern('انضم خالد إلى الطاولة.');
      expect(result, equals('خالد joined the table.'));
    });

    test('F3-4: Resolves UNO shout pattern in English mode', () {
      harness.setLocale('en');
      final result = harness.resolvePattern('هتف سارة أونو!');
      expect(result, equals('سارة shouted UNO!'));
    });

    test('F3-5: Unmatched or Arabic locale strings pass through unchanged', () {
      harness.setLocale('ar');
      final rawAr = 'لعب أحمد ورقة أحمر 7.';
      expect(harness.resolvePattern(rawAr), equals(rawAr));

      harness.setLocale('en');
      final unknown = 'رسالة عشوائية غير معروفة';
      expect(harness.resolvePattern(unknown), equals(unknown));
    });
  });
}
